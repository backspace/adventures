use axum::{
    extract::{Path, Query, State},
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use uuid::Uuid;

use crate::{render_xml::RenderXml, twilio_form::TwilioForm, AppState};

#[derive(Debug, Deserialize)]
struct Config {
    #[serde(flatten)]
    tables: HashMap<String, HashMap<String, String>>,
}

#[derive(Serialize)]
pub struct CharacterPrompts {
    character_name: String,
    prompt_names: Option<Vec<String>>,
}

pub async fn get_character_prompts(
    Key(key): Key,
    Path(character_name): Path<String>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let content = fs::read_to_string("src/prompts.toml").expect("Failed to read the prompts file");

    let config: Config = toml::from_str(&content).expect("Failed to parse the prompts file");

    let character_prompts = config.tables.get(&character_name);

    if character_prompts.is_some() {
        RenderXml(
            key,
            state.engine,
            CharacterPrompts {
                character_name,
                prompt_names: Some(character_prompts.unwrap().keys().cloned().collect()),
            },
        )
        .into_response()
    } else {
        (http::StatusCode::NOT_FOUND, "character not found").into_response()
    }
}
#[derive(Serialize)]
pub struct PromptNotFound {
    character_name: String,
    prompt_name: String,
}

pub async fn post_character_prompts(
    State(state): State<AppState>,
    Path(character_name): Path<String>,
    Form(form): Form<TwilioForm>,
) -> impl IntoResponse {
    let prompt_name = form
        .speech_result
        .to_lowercase()
        .replace(&['?', '.', ','][..], "");

    let content = fs::read_to_string("src/prompts.toml").expect("Failed to read the prompts file");

    let config: Config = toml::from_str(&content).expect("Failed to parse the prompts file");

    let character_prompts = config.tables.get(&character_name);

    let prompt = character_prompts.unwrap().get(&prompt_name);

    if prompt.is_some() {
        Redirect::to(&format!(
            "/recordings/prompts/{}/{}",
            character_name, prompt_name
        ))
        .into_response()
    } else {
        RenderXml(
            "/recordings/prompts/:character_name/not-found",
            state.engine,
            PromptNotFound {
                character_name,
                prompt_name,
            },
        )
        .into_response()
    }
}

#[derive(Serialize)]
pub struct CharacterPrompt {
    prompt_name: String,
}

pub async fn get_character_prompt(
    Key(key): Key,
    Path((character_name, prompt_name)): Path<(String, String)>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let content = fs::read_to_string("src/prompts.toml").expect("Failed to read the prompts file");

    let config: Config = toml::from_str(&content).expect("Failed to parse the prompts file");

    let character_prompts = config.tables.get(&character_name);
    let prompt = character_prompts.unwrap().get(&prompt_name);

    if prompt.is_some() {
        RenderXml(key, state.engine, CharacterPrompt { prompt_name }).into_response()
    } else {
        Redirect::to(&format!("/recordings/prompts/{}", character_name)).into_response()
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct TwilioRecordingForm {
    pub recording_url: String,
}

#[derive(Serialize)]
pub struct ConfirmRecordingPrompt {
    recording_url: String,
    action: String,
}

pub async fn post_character_prompt(
    Key(_key): Key,
    Path((character_name, prompt_name)): Path<(String, String)>,
    State(state): State<AppState>,
    Form(form): Form<TwilioRecordingForm>,
) -> impl IntoResponse {
    RenderXml(
        "/recordings/prompts/:character_name/:prompt_name/post",
        state.engine,
        ConfirmRecordingPrompt {
            recording_url: form.recording_url.to_string(),
            action: format!(
                "/recordings/prompts/{}/{}/decide?recording_url={}",
                character_name,
                prompt_name,
                urlencoding::encode(&form.recording_url)
            ),
        },
    )
}

#[derive(Deserialize)]
pub struct DecideParams {
    recording_url: String,
}

pub async fn post_character_prompt_decide(
    Key(_key): Key,
    Path((character_name, prompt_name)): Path<(String, String)>,
    params: Query<DecideParams>,
    State(state): State<AppState>,
    Form(form): Form<TwilioForm>,
) -> Redirect {
    if form.speech_result == "Keep." {
        let result = sqlx::query!(
            r#"
              INSERT INTO unmnemonic_devices.recordings (id, character_name, prompt_name, url)
              VALUES ($1, $2, $3, $4)
              ON CONFLICT (character_name, prompt_name)
              DO UPDATE SET url = EXCLUDED.url
            "#,
            Uuid::new_v4(),
            character_name,
            prompt_name,
            params.recording_url
        )
        .execute(&state.db)
        .await;

        if result.is_ok() {
            Redirect::to(&format!("/recordings/prompts/{}", character_name))
        } else {
            // How to exercise this in tests?
            Redirect::to(&format!(
                "/recordings/prompts/{}/{}",
                character_name, prompt_name
            ))
        }
    } else {
        Redirect::to(&format!(
            "/recordings/prompts/{}/{}",
            character_name, prompt_name
        ))
    }
}
