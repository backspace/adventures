use axum::{
    extract::{Path, State},
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;
use base64::{engine::general_purpose, Engine as _};
use serde::Serialize;
use serde_querystring_axum::QueryString;
use sqlx::types::Uuid;
use std::env;

use crate::{
    config::{ConfigProvider, EnvVarProvider},
    helpers::TwilioParams,
};
use crate::{render_xml::RenderXml, twilio_form::TwilioForm, AppState};

#[derive(Serialize)]
struct Teams {
    teams: Vec<Team>,
}

#[derive(sqlx::FromRow, Serialize)]
struct Team {
    id: Uuid,
    name: String,
    voicepass: String,
    excerpts: Option<Vec<String>>,
    answers: Option<Vec<String>>,
    listens: i32,
}

#[axum_macros::debug_handler]
pub async fn get_teams(Key(key): Key, State(state): State<AppState>) -> impl IntoResponse {
    let teams = sqlx::query_as::<_, Team>(
        "SELECT *, ARRAY[]::VARCHAR[] AS excerpts, ARRAY[]::VARCHAR[] AS answers FROM teams WHERE voicepass IS NOT NULL",
    )
    .fetch_all(&state.db)
    .await
    .expect("Failed to fetch team");

    RenderXml(
        key,
        state.engine,
        state.mutable_prompts.lock().unwrap().to_string(),
        Teams { teams },
    )
}

#[axum_macros::debug_handler]
pub async fn post_teams(
    State(state): State<AppState>,
    Form(form): Form<TwilioForm>,
) -> impl IntoResponse {
    let voicepass = form.speech_result;

    let team = sqlx::query_as::<_, Team>(
        "SELECT *, ARRAY[]::VARCHAR[] AS excerpts, ARRAY[]::VARCHAR[] AS answers FROM teams WHERE SIMILARITY(voicepass, $1) >= 0.65",
    )
    .bind(voicepass)
    .fetch_one(&state.db)
    .await;

    if team.is_ok() {
        Redirect::to(&format!("/teams/{}/confirm", team.unwrap().id)).into_response()
    } else {
        RenderXml(
            "/teams/not-found",
            state.engine,
            state.mutable_prompts.lock().unwrap().to_string(),
            (),
        )
        .into_response()
    }
}

#[derive(sqlx::FromRow, Serialize)]
pub struct TeamVoicepass {
    voicepass: String,
    voicepass_url: Option<String>,
}

#[axum_macros::debug_handler]
pub async fn get_confirm_team(
    Key(key): Key,
    Path(id): Path<Uuid>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let maybe_result = sqlx::query!(
        r#"
            SELECT
              voicepass, url
            FROM
              public.teams
            LEFT JOIN
              unmnemonic_devices.recordings r ON r.team_id = teams.id
            WHERE teams.id = $1
        "#,
        id
    )
    .fetch_one(&state.db)
    .await;

    if maybe_result.is_err() {
        Redirect::to("/teams").into_response()
    } else {
        let result = maybe_result.unwrap();

        if result.voicepass.is_some() {
            RenderXml(
                key,
                state.engine,
                state.mutable_prompts.lock().unwrap().to_string(),
                TeamVoicepass {
                    voicepass: result.voicepass.unwrap(),
                    voicepass_url: result.url,
                },
            )
            .into_response()
        } else {
            Redirect::to("/teams").into_response()
        }
    }
}

#[axum_macros::debug_handler]
pub async fn post_confirm_team(
    Path(id): Path<Uuid>,
    State(state): State<AppState>,
    Form(form): Form<TwilioForm>,
) -> Redirect {
    if form.speech_result.contains("yes") || form.speech_result.contains("yeah") {
        let completion_query = sqlx::query!(
            "SELECT listens > 0 AS complete FROM teams WHERE id = $1",
            id
        )
        .fetch_one(&state.db)
        .await
        .expect("Failed to fetch team listens");

        if completion_query.complete.unwrap() {
            Redirect::to(&format!("/teams/{}/complete", id))
        } else {
            Redirect::to(&format!("/teams/{}", id))
        }
    } else {
        Redirect::to("/teams")
    }
}

#[derive(Serialize)]
pub struct TeamAndMaybeEncouraging {
    team: Team,
    maybe_encouraging: Option<Recording>,
}

#[derive(sqlx::FromRow, Serialize)]
pub struct Recording {
    id: Uuid,
    url: String,
}

#[axum_macros::debug_handler]
pub async fn get_team(
    Key(key): Key,
    Path(id): Path<Uuid>,
    State(state): State<AppState>,
    params: QueryString<TwilioParams>,
) -> impl IntoResponse {
    sqlx::query!(
        r#"
          UPDATE
            unmnemonic_devices.calls
          SET
            team_id = $2
          WHERE
            id = $1;
        "#,
        params.call_sid,
        id
    )
    .execute(&state.db)
    .await
    .ok();

    let team = sqlx::query_as::<_, Team>(
        r#"
            SELECT
              t.*,
              ARRAY_AGG(LOWER(b.excerpt)) AS excerpts,
              ARRAY_AGG(LOWER(d.answer) ORDER BY d.id) AS answers
            FROM
                public.teams t
            LEFT JOIN
                unmnemonic_devices.meetings m ON t.id = m.team_id
            LEFT JOIN
                unmnemonic_devices.books b ON m.book_id = b.id
            LEFT JOIN
                unmnemonic_devices.destinations d ON m.destination_id = d.id
            WHERE
                t.id = $1
            GROUP BY
                t.id;
          "#,
    )
    .bind(id)
    .fetch_one(&state.db)
    .await
    .expect("Failed to fetch team");

    let encouraging_recording = sqlx::query_as::<_, Recording>(
        r#"
            SELECT
                r.id, r.url
            FROM
                unmnemonic_devices.recordings r
            LEFT JOIN
                unmnemonic_devices.calls c ON r.call_id = c.id
            WHERE
                r.approved AND
                r.type = 'voicemail' AND
                r.character_name = 'remember' AND
                ARRAY_LENGTH(r.team_listen_ids, 1) IS NULL AND
                (c.id IS NULL OR c.team_id != $1)
            ORDER BY r.inserted_at
            LIMIT 1
        "#,
    )
    .bind(id)
    .fetch_optional(&state.db)
    .await
    .expect("Failed to fetch recordings");

    if encouraging_recording.as_ref().is_some() {
        sqlx::query!(
            r#"
              UPDATE
                unmnemonic_devices.recordings
              SET
                team_listen_ids = ARRAY_APPEND(team_listen_ids, $1)
              WHERE
                id = $2;
            "#,
            id,
            encouraging_recording.as_ref().unwrap().id
        )
        .execute(&state.db)
        .await
        .ok();
    }

    RenderXml(
        key,
        state.engine,
        state.mutable_prompts.lock().unwrap().to_string(),
        TeamAndMaybeEncouraging {
            team,
            maybe_encouraging: encouraging_recording,
        },
    )
}

#[derive(sqlx::FromRow, Serialize)]
pub struct MeetingId {
    id: Uuid,
}

#[derive(Serialize)]
pub struct MeetingNotFound {
    team_id: Uuid,
}

#[derive(sqlx::FromRow, Serialize)]
pub struct TeamCompletion {
    matches: bool,
}

#[axum_macros::debug_handler]
pub async fn post_team(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Form(form): Form<TwilioForm>,
) -> impl IntoResponse {
    let excerpt = form.speech_result;

    let meeting_id = sqlx::query_as::<_, MeetingId>(
        r#"
          SELECT
            m.id
          FROM
            unmnemonic_devices.meetings m
            LEFT JOIN unmnemonic_devices.books b ON m.book_id = b.id
          WHERE
            m.team_id = $1
            AND SIMILARITY(LOWER(b.excerpt), $2) >= 0.65
        "#,
    )
    .bind(id)
    .bind(excerpt.clone())
    .fetch_one(&state.db)
    .await;

    if meeting_id.is_ok() {
        Redirect::to(&format!("/meetings/{}", meeting_id.unwrap().id)).into_response()
    } else {
        let completion = sqlx::query_as::<_, TeamCompletion>(
            r#"
            SELECT
              SIMILARITY(STRING_AGG(LOWER(d.answer), ' ' ORDER BY d.id), $1) >= 0.65 AS matches
            FROM
                public.teams t
            LEFT JOIN
                unmnemonic_devices.meetings m ON t.id = m.team_id
            LEFT JOIN
                unmnemonic_devices.destinations d ON m.destination_id = d.id
            WHERE
                t.id = $2
            GROUP BY
                t.id;
          "#,
        )
        .bind(excerpt)
        .bind(id)
        .fetch_one(&state.db)
        .await
        .expect("Failed to fetch team");

        if completion.matches {
            Redirect::to(&format!("/teams/{}/complete", id)).into_response()
        } else {
            RenderXml(
                "/meetings/not-found",
                state.engine,
                state.mutable_prompts.lock().unwrap().to_string(),
                MeetingNotFound { team_id: id },
            )
            .into_response()
        }
    }
}

#[axum_macros::debug_handler]
pub async fn get_complete_team(
    Path(id): Path<Uuid>,
    Key(key): Key,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let team = sqlx::query_as::<_, Team>(
        r#"
      SELECT
          t.*,
          ARRAY[]::VARCHAR[] AS excerpts,
          ARRAY[]::VARCHAR[] AS answers
      FROM
          public.teams t
      WHERE
          t.id = $1
      GROUP BY
          t.id;
      "#,
    )
    .bind(id)
    .fetch_one(&state.db)
    .await
    .expect("Failed to fetch team");

    if team.listens == 0 {
        let env_config_provider = EnvVarProvider::new(env::vars().collect());
        let config = &env_config_provider.get_config();

        let account_sid = config.twilio_account_sid.to_string();
        let api_sid = config.twilio_api_key_sid.to_string();
        let api_secret = config.twilio_api_key_secret.to_string();
        let vrs_number = config.vrs_number.to_string();
        let conductor_number = config.conductor_number.to_string();

        let create_message_body = serde_urlencoded::to_string([
            ("Body", format!("Team {} has completed", team.name)),
            ("To", conductor_number),
            ("From", vrs_number),
        ])
        .expect("Could not encode completion message creation body");

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
      public.teams
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
        (),
    )
}

#[axum_macros::debug_handler]
pub async fn post_complete_team(Path(id): Path<Uuid>, Form(form): Form<TwilioForm>) -> Redirect {
    if form.speech_result == "repeat" {
        Redirect::to(&format!("/teams/{}/complete", id))
    } else if form.speech_result.contains("record") {
        Redirect::to("/voicemails/remember")
    } else if form.speech_result == "end" {
        Redirect::to("/hangup")
    } else {
        Redirect::to("/")
    }
}
