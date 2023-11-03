use axum::{
    extract::{Path, Query, State},
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;
use base64::{engine::general_purpose, Engine as _};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use std::env;
use uuid::Uuid;

use crate::config::{ConfigProvider, EnvVarProvider};
use crate::{render_xml::RenderXml, twilio_form::TwilioRecordingForm, AppState};

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
        let env_config_provider = EnvVarProvider::new(env::vars().collect());
        let config = &env_config_provider.get_config();

        let account_sid = config.twilio_account_sid.to_string();
        let api_sid = config.twilio_api_key_sid.to_string();
        let api_secret = config.twilio_api_key_secret.to_string();
        let twilio_number = config.twilio_number.to_string();
        let notification_number = config.notification_number.to_string();

        let create_message_body = serde_urlencoded::to_string([
            (
                "Body",
                format!("There is a new voicemail for {}", character_name),
            ),
            ("To", notification_number),
            ("From", twilio_number),
        ])
        .expect("Could not encode voicemail creation message body");

        let basic_auth = format!("{}:{}", api_sid, api_secret);
        let auth_header_value = format!(
            "Basic {}",
            general_purpose::STANDARD_NO_PAD.encode(basic_auth)
        );

        let client = reqwest::Client::new();
        client
            .post(format!(
                "{}/2010-04-01/Accounts/{}/Messages.json",
                state.twilio_address, account_sid
            ))
            .header("Authorization", auth_header_value.clone())
            .header("Content-Type", "application/x-www-form-urlencoded")
            .body(create_message_body)
            .send()
            .await
            .ok();

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
