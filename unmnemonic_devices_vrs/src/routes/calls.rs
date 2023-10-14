use axum::{extract::State, response::IntoResponse};
use axum_template::{Key, RenderHtml};
use base64::{engine::general_purpose, Engine as _};
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
            .filter_map(|call| {
                Some(Call {
                    from: serde_json::from_value::<TwilioCall>(call.clone())
                        .unwrap()
                        .from,
                    start: serde_json::from_value::<TwilioCall>(call.clone())
                        .unwrap()
                        .start_time,
                })
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
