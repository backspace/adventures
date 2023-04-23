use axum::{
    extract::{Path, State},
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;
use serde::Serialize;
use sqlx::types::Uuid;
use std::collections::HashMap;

use crate::{helpers::get_prompts, render_xml::RenderXml, twilio_form::TwilioForm, AppState};

#[derive(Serialize)]
pub struct Teams {
    teams: Vec<Team>,
    prompts: HashMap<String, String>,
}

#[derive(sqlx::FromRow, Serialize)]
pub struct Team {
    id: Uuid,
    name: String,
    voicepass: String,
    excerpts: Option<Vec<String>>,
}

pub async fn get_teams(Key(key): Key, State(state): State<AppState>) -> impl IntoResponse {
    let teams = sqlx::query_as::<_, Team>("SELECT *, ARRAY[]::VARCHAR[] AS excerpts FROM teams")
        .fetch_all(&state.db)
        .await
        .expect("Failed to fetch team");

    RenderXml(
        key,
        state.engine,
        Teams {
            teams,
            prompts: get_prompts(&["pure.voicepass", "pure.silence"], state.db, state.prompts)
                .await
                .expect("Unable to find prompts"),
        },
    )
}

#[derive(Serialize)]
pub struct TeamNotFound {
    prompts: HashMap<String, String>,
}

pub async fn post_teams(
    State(state): State<AppState>,
    Form(form): Form<TwilioForm>,
) -> impl IntoResponse {
    let transformed_voicepass = form
        .speech_result
        .to_lowercase()
        .replace(&['?', '.', ','][..], "");

    let team = sqlx::query_as::<_, Team>(
        "SELECT *, ARRAY[]::VARCHAR[] AS excerpts FROM teams WHERE voicepass = $1",
    )
    .bind(transformed_voicepass)
    .fetch_one(&state.db)
    .await;

    if team.is_ok() {
        Redirect::to(&format!("/teams/{}/confirm", team.unwrap().id)).into_response()
    } else {
        RenderXml(
            "/teams/not-found",
            state.engine,
            TeamNotFound {
                prompts: get_prompts(&["pure.voicepass_not_found"], state.db, state.prompts)
                    .await
                    .expect("Unable to get prompts"),
            },
        )
        .into_response()
    }
}

#[derive(sqlx::FromRow, Serialize)]
pub struct TeamVoicepass {
    voicepass: String,
}

pub async fn get_confirm_team(
    Key(key): Key,
    Path(id): Path<Uuid>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let maybe_result = sqlx::query!("SELECT voicepass FROM teams WHERE id = $1", id)
        .fetch_one(&state.db)
        .await;

    // println!("result? {:?}", result);
    if maybe_result.is_err() {
        Redirect::to("/teams").into_response()
    } else {
        let result = maybe_result.unwrap();

        if result.voicepass.is_some() {
            RenderXml(
                key,
                state.engine,
                TeamVoicepass {
                    voicepass: result.voicepass.unwrap(),
                },
            )
            .into_response()
        } else {
            Redirect::to("/teams").into_response()
        }
    }
}

pub async fn post_confirm_team(Path(id): Path<Uuid>, Form(form): Form<TwilioForm>) -> Redirect {
    if form.speech_result == "Yes." {
        Redirect::to(&format!("/teams/{}", id))
    } else {
        Redirect::to("/teams")
    }
}

pub async fn get_team(
    Key(key): Key,
    Path(id): Path<Uuid>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let team = sqlx::query_as::<_, Team>(
        r#"
            SELECT
              t.*,
              ARRAY_AGG(b.excerpt) AS excerpts
            FROM
                public.teams t
            LEFT JOIN
                unmnemonic_devices.meetings m ON t.id = m.team_id
            LEFT JOIN
                unmnemonic_devices.books b ON m.book_id = b.id
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

    RenderXml(key, state.engine, team)
}

#[derive(sqlx::FromRow, Serialize)]
pub struct MeetingId {
    id: Uuid,
}

#[derive(Serialize)]
pub struct MeetingNotFound {
    team_id: Uuid,
    prompts: HashMap<String, String>,
}

pub async fn post_team(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Form(form): Form<TwilioForm>,
) -> impl IntoResponse {
    let transformed_excerpt = form
        .speech_result
        .to_lowercase()
        .replace(&['?', '.', ','][..], "");

    let meeting_id = sqlx::query_as::<_, MeetingId>(
        r#"
          SELECT
            m.id
          FROM
            unmnemonic_devices.meetings m
            LEFT JOIN unmnemonic_devices.books b ON m.book_id = b.id
          WHERE
            m.team_id = $1
            AND b.excerpt = $2
        "#,
    )
    .bind(id)
    .bind(transformed_excerpt)
    .fetch_one(&state.db)
    .await;

    if meeting_id.is_ok() {
        Redirect::to(&format!("/meetings/{}", meeting_id.unwrap().id)).into_response()
    } else {
        RenderXml(
            "/meetings/not-found",
            state.engine,
            MeetingNotFound {
                team_id: id,
                prompts: get_prompts(&["pure.phrase_not_found"], state.db, state.prompts)
                    .await
                    .expect("Unable to get prompts"),
            },
        )
        .into_response()
    }
}
