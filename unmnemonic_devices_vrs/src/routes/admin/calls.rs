use axum::{
    extract::{Form, State},
    response::{IntoResponse, Response},
};
use axum_template::{Key, RenderHtml};
use base64::{engine::general_purpose, Engine as _};
use http::StatusCode;
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, env};

use crate::auth::User;
use crate::config::{ConfigProvider, EnvVarProvider};
use crate::AppState;

#[derive(Debug, Deserialize)]
struct TwilioCall {
    sid: String,
    from: String,
    start_time: String,
}

#[derive(Serialize)]
pub struct Calls {
    calls: Vec<Call>,
}

#[derive(sqlx::FromRow, Serialize)]
pub struct Call {
    sid: String,
    from: String,
    start: String,
    team_name: Option<String>,
}

#[derive(sqlx::FromRow, Serialize)]
pub struct CallWithTeam {
    call_id: String,
    team_name: String,
}

#[axum_macros::debug_handler]
pub async fn get_calls(
    Key(key): Key,
    State(state): State<AppState>,
    _user: User,
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

    let mut active_calls = response["calls"].as_array().map(|calls| {
        calls
            .iter()
            .map(|call| Call {
                sid: serde_json::from_value::<TwilioCall>(call.clone())
                    .unwrap()
                    .sid,
                from: serde_json::from_value::<TwilioCall>(call.clone())
                    .unwrap()
                    .from,
                start: serde_json::from_value::<TwilioCall>(call.clone())
                    .unwrap()
                    .start_time,
                team_name: None,
            })
            .collect::<Vec<Call>>()
    });

    let active_call_ids: Vec<String> = active_calls.as_ref().map_or(vec![], |calls| {
        calls.iter().map(|call| call.sid.clone()).collect()
    });

    let call_teams = sqlx::query_as::<_, CallWithTeam>(
        "
          SELECT c.id as call_id, t.name as team_name
          FROM unmnemonic_devices.calls c
          JOIN teams t ON c.team_id = t.id
          WHERE c.id = ANY($1)
        ",
    )
    .bind(active_call_ids)
    .fetch_all(&state.db)
    .await
    .expect("Unable to fetch call teams");

    let call_to_team_name: HashMap<String, String> = call_teams
        .into_iter()
        .map(|ct| (ct.call_id, ct.team_name))
        .collect();

    for mut call in active_calls.as_mut().unwrap() {
        if let Some(team_name) = call_to_team_name.get(&call.sid) {
            call.team_name = Some(team_name.clone());
        }
    }

    RenderHtml(
        key.chars().skip(1).collect::<String>(),
        state.engine,
        Calls {
            calls: active_calls.unwrap(),
        },
    )
}

#[derive(Deserialize)]
pub struct CreateCallParams {
    sid: String,
    to: String,
}

#[axum_macros::debug_handler]
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

    let conference_url = format!("{}conferences/{}", root_url, params.sid);

    let create_call_body = serde_urlencoded::to_string([
        ("Method", "GET".to_string()),
        ("Url", conference_url.clone()),
        ("To", params.to.to_string()),
        ("From", twilio_number),
    ])
    .expect("Could not encode call creation body");

    let client = reqwest::Client::new();
    let create_call_response = client
        .post(format!(
            "{}/2010-04-01/Accounts/{}/Calls.json",
            state.twilio_address, account_sid
        ))
        .header("Authorization", auth_header_value.clone())
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(create_call_body)
        .send()
        .await;

    if create_call_response.is_ok() {
        let ok_create_call_response = create_call_response.unwrap();

        if ok_create_call_response.status().is_success() {
            let update_call_body = serde_urlencoded::to_string([
                ("Method", "GET".to_string()),
                ("Url", conference_url),
            ])
            .expect("Could not encode call update body");

            let update_call_response = client
                .post(format!(
                    "{}/2010-04-01/Accounts/{}/Calls/{}.json",
                    state.twilio_address, account_sid, params.sid
                ))
                .header("Authorization", auth_header_value)
                .header("Content-Type", "application/x-www-form-urlencoded")
                .body(update_call_body)
                .send()
                .await;

            if update_call_response.is_ok() {
                let ok_update_call_response = update_call_response.unwrap();

                if ok_update_call_response.status().is_success() {
                    StatusCode::NO_CONTENT.into_response()
                } else {
                    let response_body = ok_update_call_response.bytes().await.unwrap();
                    (StatusCode::BAD_REQUEST, response_body).into_response()
                }
            } else {
                StatusCode::BAD_REQUEST.into_response()
            }
        } else {
            let response_body = ok_create_call_response.bytes().await.unwrap();
            (StatusCode::BAD_REQUEST, response_body).into_response()
        }
    } else {
        StatusCode::BAD_REQUEST.into_response()
    }
}
