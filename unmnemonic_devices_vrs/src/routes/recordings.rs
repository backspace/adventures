use axum::{
    extract::{Path, Query, State},
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

use crate::{render_xml::RenderXml, twilio_form::TwilioForm, AppState};

#[derive(Serialize)]
pub struct CharacterPrompts {
    character_name: String,
    prompt_names: Option<Vec<String>>,
    add_unrecorded: bool,
}

pub async fn get_character_prompts(
    Key(key): Key,
    Path(character_name): Path<String>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let character_prompts = state.prompts.tables.get(&character_name);

    if character_prompts.is_some() {
        let unrecorded_prompt_name_option = find_unrecorded_prompt(
            state.db,
            character_name.to_string(),
            character_prompts.unwrap().keys(),
        )
        .await
        .unwrap();

        RenderXml(
            key,
            state.engine,
            CharacterPrompts {
                character_name,
                prompt_names: Some(character_prompts.unwrap().keys().cloned().collect()),
                add_unrecorded: unrecorded_prompt_name_option.is_some(),
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

#[derive(Serialize)]
pub struct UnrecordedIntroduction {
    character_name: String,
    redirect: String,
}

pub async fn post_character_prompts(
    State(state): State<AppState>,
    Path(character_name): Path<String>,
    Form(form): Form<TwilioForm>,
) -> impl IntoResponse {
    let character_prompts = state.prompts.tables.get(&character_name);
    if form.speech_result == "Unrecorded prompts." {
        let unrecorded_prompt_name_option = find_unrecorded_prompt(
            state.db,
            character_name.to_string(),
            character_prompts.unwrap().keys(),
        )
        .await
        .unwrap();

        if unrecorded_prompt_name_option.is_some() {
            RenderXml(
                "/recordings/prompts/:character_name/unrecorded",
                state.engine,
                UnrecordedIntroduction {
                    character_name: character_name.to_string(),
                    redirect: format!(
                        "/recordings/prompts/{}/{}?unrecorded",
                        character_name,
                        unrecorded_prompt_name_option.unwrap()
                    ),
                },
            )
            .into_response()
        } else {
            RenderXml(
                "/recordings/prompts/:character_name/no-unrecorded",
                state.engine,
                UnrecordedIntroduction {
                    character_name: character_name.to_string(),
                    redirect: format!("/recordings/prompts/{}", character_name),
                },
            )
            .into_response()
        }
    } else {
        let prompt_name = form
            .speech_result
            .to_lowercase()
            .replace(&['?', '.', ','][..], "");

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
}

#[derive(Serialize)]
pub struct CharacterPrompt {
    character_name: String,
    prompt_name: String,
    unrecorded_query_param: bool,
}

#[derive(Deserialize)]
pub struct MaybeRecordingParams {
    unrecorded: Option<String>,
}

pub async fn get_character_prompt(
    Key(key): Key,
    Path((character_name, prompt_name)): Path<(String, String)>,
    State(state): State<AppState>,
    params: Query<MaybeRecordingParams>,
) -> impl IntoResponse {
    let character_prompts = state.prompts.tables.get(&character_name);
    let prompt = character_prompts.unwrap().get(&prompt_name);

    if prompt.is_some() {
        RenderXml(
            key,
            state.engine,
            CharacterPrompt {
                character_name,
                prompt_name,
                unrecorded_query_param: params.unrecorded.is_some(),
            },
        )
        .into_response()
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
    params: Query<MaybeRecordingParams>,
    Form(form): Form<TwilioRecordingForm>,
) -> impl IntoResponse {
    RenderXml(
        "/recordings/prompts/:character_name/:prompt_name/post",
        state.engine,
        ConfirmRecordingPrompt {
            recording_url: form.recording_url.to_string(),
            action: format!(
                "/recordings/prompts/{}/{}/decide?recording_url={}{}",
                character_name,
                prompt_name,
                urlencoding::encode(&form.recording_url),
                if params.unrecorded.is_some() {
                    "&unrecorded"
                } else {
                    ""
                }
            ),
        },
    )
}

#[derive(Deserialize)]
pub struct DecideParams {
    recording_url: String,
    unrecorded: Option<String>,
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
            Redirect::to(&format!(
                "/recordings/prompts/{}{}",
                character_name,
                if params.unrecorded.is_some() {
                    "?unrecorded"
                } else {
                    ""
                }
            ))
        } else {
            // How to exercise this in tests?
            Redirect::to(&format!(
                "/recordings/prompts/{}/{}{}",
                character_name,
                prompt_name,
                if params.unrecorded.is_some() {
                    "?unrecorded"
                } else {
                    ""
                }
            ))
        }
    } else {
        Redirect::to(&format!(
            "/recordings/prompts/{}/{}{}",
            character_name,
            prompt_name,
            if params.unrecorded.is_some() {
                "?unrecorded"
            } else {
                ""
            }
        ))
    }
}

async fn find_unrecorded_prompt(
    db: PgPool,
    character_name: String,
    prompts: impl Iterator<Item = &String>,
) -> Result<Option<String>, sqlx::Error> {
    let prompts: Vec<&str> = prompts.map(AsRef::as_ref).collect();

    let result = sqlx::query_as::<_, (String,)>(
        r#"
              SELECT
                *
              FROM
                UNNEST($1) AS all_prompts
              WHERE
                all_prompts NOT IN (
                  SELECT
                    prompt_name
                  FROM
                    unmnemonic_devices.recordings
                  WHERE
                    character_name = $2
                    AND url IS NOT NULL
                )
              ORDER BY all_prompts
              LIMIT 1
            "#,
    )
    .bind(prompts)
    .bind(character_name)
    .fetch_optional(&db)
    .await?;

    Ok(result.map(|tuple| tuple.0))
}
