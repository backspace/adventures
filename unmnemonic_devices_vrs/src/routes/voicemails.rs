use axum::{
    extract::{Path, Query, State},
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

use crate::{
    helpers::get_all_prompts, render_xml::RenderXml, twilio_form::TwilioRecordingForm, AppState,
};

#[derive(Serialize)]
pub struct CharacterVoicemail {
    character_name: String,
    prompt_name: String,
}

#[axum_macros::debug_handler]
pub async fn get_character_voicemail(
    Key(key): Key,
    Path(character_name): Path<String>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    RenderXml(
        key,
        state.engine,
        state.mutable_prompts.lock().unwrap().to_string(),
        CharacterVoicemail {
            character_name: character_name.clone(),
            prompt_name: format!("{}.voicemail", character_name),
        },
    )
    .into_response()
}

#[axum_macros::debug_handler]
pub async fn post_character_voicemail(
    Key(_key): Key,
    Path(character_name): Path<String>,
    State(state): State<AppState>,
    Form(form): Form<TwilioRecordingForm>,
) -> impl IntoResponse {
    let uuid = Uuid::new_v4();
    let result = sqlx::query!(
        r#"
              INSERT INTO unmnemonic_devices.recordings (id, character_name, prompt_name, type, url)
              VALUES ($1, $2, $3, $4, $5)
            "#,
        uuid.clone(),
        character_name,
        uuid.to_string(),
        "voicemail",
        form.recording_url
    )
    .execute(&state.db)
    .await;

    if result.is_ok() {
        RenderXml(
            "/voicemails/:character_name/success",
            state.engine,
            state.mutable_prompts.lock().unwrap().to_string(),
            (),
        )
        .into_response()
    } else {
        Redirect::to("/hangup").into_response()
    }
}
