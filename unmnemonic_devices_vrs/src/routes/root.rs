use axum::{
    extract::Query,
    extract::State,
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;
use base64::{engine::general_purpose, Engine as _};
use serde::{Deserialize, Serialize};
use serde_querystring_axum::QueryString;

use crate::{render_xml::RenderXml, twilio_form::TwilioForm, AppState};

#[derive(Deserialize)]
pub struct RootParams {
    begun: Option<String>,
    #[serde(rename = "CallSid")]
    call_sid: Option<String>,
    #[serde(rename = "Caller")]
    caller: Option<String>,
}

#[derive(Serialize)]
struct Settings {
    begun: bool,
    override_message: Option<String>,
}

#[axum_macros::debug_handler]
pub async fn get_prerecord(Key(key): Key, State(state): State<AppState>) -> impl IntoResponse {
    RenderXml(
        key,
        state.engine,
        state.mutable_prompts.lock().unwrap().to_string(),
        (),
    )
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
    let config = state.config;
    let account_sid = config.twilio_account_sid.to_string();
    let api_sid = config.twilio_api_key_sid.to_string();
    let api_secret = config.twilio_api_key_secret.to_string();

    let basic_auth = format!("{}:{}", api_sid, api_secret);
    let auth_header_value = format!(
        "Basic {}",
        general_purpose::STANDARD_NO_PAD.encode(basic_auth)
    );

    let client = reqwest::Client::new();
    let result = client
        .post(format!(
            "{}/2010-04-01/Accounts/{}/Calls/{}/Recordings.json",
            state.twilio_address, account_sid, params.call_sid
        ))
        .header("Authorization", auth_header_value)
        .send()
        .await
        .unwrap()
        .json::<serde_json::Value>()
        .await;

    println!("Recording request result {:?}", result);

    RenderXml(
        key,
        state.engine,
        state.mutable_prompts.lock().unwrap().to_string(),
        (),
    )
}

#[derive(Serialize)]
pub struct RootData {
    begun: bool,
    ending: bool,
    override_message: Option<String>,
    character_names: Vec<String>,
}

#[axum_macros::debug_handler]
pub async fn get_root(
    Key(key): Key,
    State(state): State<AppState>,
    params: QueryString<RootParams>,
) -> impl IntoResponse {
    sqlx::query!(
        r#"
          INSERT INTO unmnemonic_devices.calls (id, number)
          VALUES ($1, $2)
        "#,
        params.call_sid,
        params.caller,
    )
    .execute(&state.db)
    .await
    .ok();

    let settings =
        sqlx::query!("SELECT begun, ending, override as override_message, notify_supervisor FROM unmnemonic_devices.settings LIMIT 1")
            .fetch_one(&state.db)
            .await
            .expect("Failed to fetch settings");

    let config = state.config;
    let supervisor_number = config.supervisor_number.to_string();
    let conductor_number = config.conductor_number.to_string();

    let caller_is_conductor =
        params.caller.clone().unwrap_or("NOTHING".to_string()) == conductor_number;
    let caller_is_supervisor =
        params.caller.clone().unwrap_or("NOTHING".to_string()) == supervisor_number;

    let notify_supervisor = settings.begun.unwrap()
        && !settings.ending.unwrap()
        && !caller_is_supervisor
        && settings.notify_supervisor.unwrap();
    let notify_conductor = params.caller.is_some()
        && !settings.begun.unwrap()
        && !caller_is_supervisor
        && !caller_is_conductor;

    let account_sid = config.twilio_account_sid.to_string();
    let api_sid = config.twilio_api_key_sid.to_string();
    let api_secret = config.twilio_api_key_secret.to_string();
    let vrs_number = config.vrs_number.to_string();

    let client = reqwest::Client::new();

    let basic_auth = format!("{}:{}", api_sid, api_secret);
    let auth_header_value = format!(
        "Basic {}",
        general_purpose::STANDARD_NO_PAD.encode(basic_auth)
    );

    if notify_conductor {
        let create_message_body = serde_urlencoded::to_string([
            (
                "Body",
                format!("New call from {}", params.caller.clone().unwrap()),
            ),
            ("To", supervisor_number),
            ("From", vrs_number),
        ])
        .expect("Could not encode meeting message creation body");

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
    } else if notify_supervisor {
        let create_message_body = serde_urlencoded::to_string([
            (
                "Body",
                format!("New call from {}", params.caller.clone().unwrap()),
            ),
            ("To", supervisor_number),
            ("From", vrs_number),
        ])
        .expect("Could not encode meeting message creation body");

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
    }

    RenderXml(
        key,
        state.engine,
        state.mutable_prompts.lock().unwrap().to_string(),
        RootData {
            begun: settings.begun.unwrap() || params.begun.is_some(),
            ending: settings.ending.unwrap(),
            override_message: settings.override_message,
            character_names: state
                .prompts
                .tables
                .keys()
                .cloned()
                .collect::<Vec<String>>(),
        },
    )
}

#[axum_macros::debug_handler]
pub async fn post_root(State(state): State<AppState>, Form(form): Form<TwilioForm>) -> Redirect {
    let settings =
        sqlx::query!("SELECT begun, ending, override as override_message FROM unmnemonic_devices.settings LIMIT 1")
            .fetch_optional(&state.db)
            .await
            .expect("Failed to fetch settings");

    if settings.is_some()
        && settings.as_ref().unwrap().begun.is_some()
        && settings.unwrap().begun.unwrap()
    {
        if form.speech_result == "recordings" {
            Redirect::to("/recordings/confirm")
        } else {
            Redirect::to("/teams")
        }
    } else if form.speech_result == "remember" {
        Redirect::to("/voicemails/remember/confirm")
    } else {
        let character_names = state
            .prompts
            .tables
            .keys()
            .cloned()
            .collect::<Vec<String>>();

        if character_names.contains(&form.speech_result) {
            Redirect::to(&format!("/voicemails/{}", form.speech_result))
        } else if form.speech_result == "begun" {
            Redirect::to("/?begun")
        } else if form.speech_result == "recordings" {
            Redirect::to("/recordings/confirm")
        } else {
            Redirect::to("/")
        }
    }
}
