use axum::{
    extract::{Path, State},
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;
use base64::{engine::general_purpose, Engine as _};
use serde::Serialize;
use std::env;
use uuid::Uuid;

use crate::config::{ConfigProvider, EnvVarProvider};
use crate::{
    render_xml::RenderXml,
    twilio_form::{TwilioForm, TwilioRecordingForm},
    AppState,
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
              INSERT INTO unmnemonic_devices.recordings (id, character_name, prompt_name, type, url, call_id)
              VALUES ($1, $2, $3, $4, $5, $6)
            "#,
        uuid.clone(),
        character_name,
        uuid.to_string(),
        "voicemail",
        form.recording_url,
        form.call_sid
    )
    .execute(&state.db)
    .await;

    println!("result? {:?}", result);

    if result.is_ok() {
        let env_config_provider = EnvVarProvider::new(env::vars().collect());
        let config = &env_config_provider.get_config();

        let account_sid = config.twilio_account_sid.to_string();
        let api_sid = config.twilio_api_key_sid.to_string();
        let api_secret = config.twilio_api_key_secret.to_string();
        let vrs_number = config.vrs_number.to_string();
        let notification_number = config.notification_number.to_string();

        let create_message_body = serde_urlencoded::to_string([
            (
                "Body",
                format!("There is a new voicemail for {}", character_name),
            ),
            ("To", notification_number),
            ("From", vrs_number),
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

#[derive(Serialize)]
pub struct UserVoicepasses {
    voicepasses: Vec<UserVoicepass>,
}

#[derive(sqlx::FromRow, Serialize)]
pub struct UserVoicepass {
    voicepass: String,
}

#[axum_macros::debug_handler]
pub async fn get_voicemails_remember_confirm(
    Key(key): Key,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let user_voicepasses = sqlx::query_as::<_, UserVoicepass>(
        "SELECT voicepass FROM users WHERE voicepass IS NOT NULL",
    )
    .fetch_all(&state.db)
    .await
    .expect("Failed to fetch users");

    RenderXml(
        key,
        state.engine,
        state.mutable_prompts.lock().unwrap().to_string(),
        UserVoicepasses {
            voicepasses: user_voicepasses,
        },
    )
}

#[derive(sqlx::FromRow, Serialize)]
pub struct UserEmail {
    id: Uuid,
    email: String,
}

#[axum_macros::debug_handler]
pub async fn post_voicemails_remember_confirm(
    State(state): State<AppState>,
    Form(form): Form<TwilioForm>,
) -> impl IntoResponse {
    let voicepass = form.speech_result;

    let user = sqlx::query_as::<_, UserEmail>(
        "SELECT id, email FROM users WHERE SIMILARITY(voicepass, $1) >= 0.75",
    )
    .bind(&voicepass)
    .fetch_one(&state.db)
    .await;

    let env_config_provider = EnvVarProvider::new(env::vars().collect());
    let config = &env_config_provider.get_config();

    let account_sid = config.twilio_account_sid.to_string();
    let api_sid = config.twilio_api_key_sid.to_string();
    let api_secret = config.twilio_api_key_secret.to_string();
    let vrs_number = config.vrs_number.to_string();
    let notification_number = config.notification_number.to_string();

    let basic_auth = format!("{}:{}", api_sid, api_secret);
    let auth_header_value = format!(
        "Basic {}",
        general_purpose::STANDARD_NO_PAD.encode(basic_auth)
    );

    let client = reqwest::Client::new();

    if user.is_ok() {
        let create_message_body = serde_urlencoded::to_string([
            (
                "Body",
                format!("User {} has remembered", user.as_ref().unwrap().email),
            ),
            ("To", notification_number),
            ("From", vrs_number),
        ])
        .expect("Could not encode completion message creation body");

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

        sqlx::query!(
            r#"
              UPDATE
                public.users
              SET
                remembered = remembered + 1
              WHERE
                id = $1;
            "#,
            user.unwrap().id
        )
        .execute(&state.db)
        .await
        .ok();

        RenderXml(
            "/voicemails/remember/confirm-success",
            state.engine,
            state.mutable_prompts.lock().unwrap().to_string(),
            (),
        )
        .into_response()
    } else {
        let create_message_body = serde_urlencoded::to_string([
            ("Body", format!("Failed to confirm remember: {}", voicepass)),
            ("To", notification_number),
            ("From", vrs_number),
        ])
        .expect("Could not encode failure message creation body");

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
            "/voicemails/remember/confirm-not-found",
            state.engine,
            state.mutable_prompts.lock().unwrap().to_string(),
            (),
        )
        .into_response()
    }
}
