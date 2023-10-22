use axum::{
    extract::{Form, State},
    response::{IntoResponse, Response},
};
use axum_template::{Key, RenderHtml};
use base64::{engine::general_purpose, Engine as _};
use http::StatusCode;
use serde::{Deserialize, Serialize};
use std::env;

use crate::config::{ConfigProvider, EnvVarProvider};
use crate::AppState;

#[derive(Debug, Deserialize)]
struct TwilioCall {
    from: String,
    start_time: String,
}

#[derive(Serialize)]
pub struct Calls {
    calls: Vec<Call>,
}

#[derive(sqlx::FromRow, Serialize)]
pub struct Call {
    from: String,
    start: String,
}

pub async fn get_calls(Key(key): Key, State(state): State<AppState>) -> impl IntoResponse {
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
    let response = client
        .get(format!(
            "{}/2010-04-01/Accounts/{}/Calls.json?Status=in-progress",
            state.twilio_address, account_sid
        ))
        .header("Authorization", auth_header_value)
        .send()
        .await
        .unwrap()
        .json::<serde_json::Value>()
        .await
        .unwrap();

    let calls = response["calls"].as_array().map(|calls| {
        calls
            .iter()
            .map(|call| Call {
                from: serde_json::from_value::<TwilioCall>(call.clone())
                    .unwrap()
                    .from,
                start: serde_json::from_value::<TwilioCall>(call.clone())
                    .unwrap()
                    .start_time,
            })
            .collect::<Vec<Call>>()
    });

    RenderHtml(
        key.chars().skip(1).collect::<String>(),
        state.engine,
        Calls {
            calls: calls.unwrap(),
        },
    )
}

#[derive(Deserialize)]
pub struct CreateCallParams {
    to: String,
}

pub async fn post_calls(
    State(state): State<AppState>,
    Form(params): Form<CreateCallParams>,
) -> Response {
    let env_config_provider = EnvVarProvider::new(env::vars().collect());
    let config = &env_config_provider.get_config();
    let account_sid = config.twilio_account_sid.to_string();
    let api_sid = config.twilio_api_key_sid.to_string();
    let api_secret = config.twilio_api_key_secret.to_string();

    let twilio_number = config.twilio_number.to_string();
    let root_url = config.root_url.to_string();

    let basic_auth = format!("{}:{}", api_sid, api_secret);
    let auth_header_value = format!(
        "Basic {}",
        general_purpose::STANDARD_NO_PAD.encode(basic_auth)
    );

    let body = serde_urlencoded::to_string([
        ("Url", root_url),
        ("Method", "GET".to_string()),
        ("To", params.to.to_string()),
        ("From", twilio_number),
    ])
    .expect("Could not encode");

    let client = reqwest::Client::new();
    let response = client
        .post(format!(
            "{}/2010-04-01/Accounts/{}/Calls.json",
            state.twilio_address, account_sid
        ))
        .header("Authorization", auth_header_value)
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(body)
        .send()
        .await;

    if response.is_ok() {
        let ok_response = response.unwrap();

        if ok_response.status().is_success() {
            StatusCode::NO_CONTENT.into_response()
        } else {
            let response_body = ok_response.bytes().await.unwrap();
            (StatusCode::BAD_REQUEST, response_body).into_response()
        }
    } else {
        StatusCode::BAD_REQUEST.into_response()
    }
}
