use axum::{
    extract::Query,
    extract::State,
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;
use base64::{engine::general_purpose, Engine as _};
use serde::{Deserialize, Serialize};
use std::env;

use crate::config::{ConfigProvider, EnvVarProvider};
use crate::{render_xml::RenderXml, twilio_form::TwilioForm, AppState};

#[derive(Deserialize)]
pub struct RootParams {
    begun: Option<String>,
}

#[derive(Serialize)]
struct Settings {
    begun: bool,
}

#[axum_macros::debug_handler]
pub async fn get_prerecord(Key(key): Key, State(state): State<AppState>) -> impl IntoResponse {
    RenderXml(key, state.engine, state.serialised_prompts, ())
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct TwilioParams {
    call_sid: String,
}

#[axum_macros::debug_handler]
pub async fn get_record(
    Key(key): Key,
    State(state): State<AppState>,
    params: Query<TwilioParams>,
) -> impl IntoResponse {
    let env_config_provider = EnvVarProvider::new(env::vars().collect());
    let config = &env_config_provider.get_config();
    let account_sid = config.twilio_account_sid.to_string();
    let api_sid = config.twilio_api_key_sid.to_string();
    let api_secret = config.twilio_api_key_secret.to_string();

    let basic_auth = format!("{}:{}", api_sid, api_secret);
    let auth_header_value = format!(
        "Basic {}",
        general_purpose::STANDARD_NO_PAD.encode(basic_auth)
    );

    let client = reqwest::Client::new();
    client
        .post(format!(
            "{}/2010-04-01/Accounts/{}/Calls/{}/Recordings.json",
            state.twilio_address, account_sid, params.call_sid
        ))
        .header("Authorization", auth_header_value)
        .send()
        .await
        .unwrap()
        .json::<serde_json::Value>()
        .await
        .ok();

    RenderXml(key, state.engine, state.serialised_prompts, ())
}

#[derive(Serialize)]
pub struct RootData {
    begun: bool,
    down: bool,
    ending: bool,
}

#[axum_macros::debug_handler]
pub async fn get_root(
    Key(key): Key,
    State(state): State<AppState>,
    params: Query<RootParams>,
) -> impl IntoResponse {
    let settings =
        sqlx::query!("SELECT begun, down, ending FROM unmnemonic_devices.settings LIMIT 1")
            .fetch_one(&state.db)
            .await
            .expect("Failed to fetch settings");

    RenderXml(
        key,
        state.engine,
        state.serialised_prompts,
        RootData {
            begun: settings.begun.unwrap() || params.begun.is_some(),
            down: settings.down.unwrap(),
            ending: settings.ending.unwrap(),
        },
    )
}

#[axum_macros::debug_handler]
pub async fn post_root(Form(form): Form<TwilioForm>) -> Redirect {
    if form.speech_result == "Begun." {
        Redirect::to("/?begun")
    } else {
        Redirect::to("/")
    }
}
