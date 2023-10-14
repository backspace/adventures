use axum::{extract::State, response::IntoResponse};
use axum_template::{Key, RenderHtml};
use serde::{Deserialize, Serialize};
use std::env;

use openapi::apis::api20100401_call_api::{list_call, ListCallParams};
use openapi::apis::configuration::Configuration;

use crate::config::{ConfigProvider, EnvVarProvider};
use crate::AppState;

#[derive(Debug, Deserialize)]
struct TwilioCall {
    from: String,
}

#[derive(Serialize)]
pub struct Calls {
    calls: Vec<Call>,
}

#[derive(sqlx::FromRow, Serialize)]
pub struct Call {
    from: String,
}

pub async fn get_calls(Key(key): Key, State(state): State<AppState>) -> impl IntoResponse {
    let env_config_provider = EnvVarProvider::new(env::vars().collect());
    let config = &env_config_provider.get_config();
    let account_sid = config.twilio_account_sid.to_string();
    let auth_token = config.twilio_auth_token.to_string();

    let twilio_config = Configuration {
        basic_auth: Some((account_sid.clone(), Some(auth_token))),
        ..Default::default()
    };

    let response = list_call(
        &twilio_config,
        ListCallParams {
            account_sid: account_sid.clone(),
            to: None,
            from: None,
            parent_call_sid: None,
            status: None,
            start_time: None,
            start_time_less_than: None,
            start_time_greater_than: None,
            end_time: None,
            end_time_less_than: None,
            end_time_greater_than: None,
            page_size: None,
            page: None,
            page_token: None,
        },
    )
    .await;

    match response {
        Ok(result) => {
            let calls = result
                .calls
                .unwrap()
                .iter()
                .map(|call| Call {
                    from: call.from.clone().unwrap().unwrap(),
                })
                .collect::<Vec<Call>>();

            RenderHtml(
                key.chars().skip(1).collect::<String>(),
                state.engine,
                Calls { calls },
            )
        }
        Err(error) => RenderHtml(
            key.chars().skip(1).collect::<String>(),
            state.engine,
            Calls { calls: Vec::new() },
        ),
    };
}
