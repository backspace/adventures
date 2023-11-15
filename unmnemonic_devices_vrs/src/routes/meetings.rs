use axum::{
    extract::{Path, State},
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;
use serde::Serialize;
use sqlx::types::Uuid;

use crate::config::{ConfigProvider, EnvVarProvider};
use crate::{render_xml::RenderXml, twilio_form::TwilioForm, AppState};
use base64::{engine::general_purpose, Engine as _};
use std::env;

#[derive(sqlx::FromRow, Serialize)]
pub struct Meeting {
    team_name: String,
    region_name: String,
    region_recording_url: Option<String>,
    description: String,
    destination_recording_url: Option<String>,
    book_title: String,
    unlistened: bool,
}

#[derive(Serialize)]
pub struct MeetingTemplate {
    name: String,
    description: String,
    name_recording: Option<String>,
    description_recording: Option<String>,
}

#[axum_macros::debug_handler]
pub async fn get_meeting(
    Key(key): Key,
    Path(id): Path<Uuid>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let meeting = sqlx::query_as::<_, Meeting>(
        r#"
          SELECT
            t.name as team_name,
            b.title as book_title,
            r.name as region_name,
            d.description,
            m.listens = 0 as unlistened,
            rr.url as region_recording_url,
            dr.url as destination_recording_url
          FROM
              unmnemonic_devices.meetings m
          LEFT JOIN
              unmnemonic_devices.books b ON m.book_id = b.id
          LEFT JOIN
              unmnemonic_devices.destinations d ON m.destination_id = d.id
          LEFT JOIN
              unmnemonic_devices.regions r ON d.region_id = r.id
          LEFT JOIN
              public.teams t ON m.team_id = t.id
          LEFT JOIN
              unmnemonic_devices.recordings rr ON rr.region_id = r.id
          LEFT JOIN
              unmnemonic_devices.recordings dr ON dr.destination_id = d.id
          WHERE
              m.id = $1;
        "#,
    )
    .bind(id)
    .fetch_one(&state.db)
    .await
    .expect("Failed to fetch meeting");

    if meeting.unlistened {
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
                format!(
                    "Team: {}\nBook: {}\nDest: {}",
                    meeting.team_name, meeting.book_title, meeting.region_name
                ),
            ),
            ("To", notification_number),
            ("From", twilio_number),
        ])
        .expect("Could not encode meeting message creation body");

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
    }

    sqlx::query!(
        r#"
      UPDATE
        unmnemonic_devices.meetings
      SET
        listens = listens + 1
      WHERE
        id = $1;
    "#,
        id
    )
    .execute(&state.db)
    .await
    .ok();

    RenderXml(
        key,
        state.engine,
        state.mutable_prompts.lock().unwrap().to_string(),
        MeetingTemplate {
            name: meeting.region_name,
            description: meeting.description,
            name_recording: meeting.region_recording_url,
            description_recording: meeting.destination_recording_url,
        },
    )
}

#[axum_macros::debug_handler]
pub async fn post_meeting(Path(id): Path<Uuid>, Form(form): Form<TwilioForm>) -> Redirect {
    if form.speech_result.as_str().contains("record") {
        Redirect::to("/voicemails/remember")
    } else {
        match form.speech_result.as_str() {
            "end" => Redirect::to("/hangup"),
            _ => Redirect::to(&format!("/meetings/{}", id)),
        }
    }
}
