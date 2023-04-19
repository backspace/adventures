use axum::{
    extract::{Path, State},
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;

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
