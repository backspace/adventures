use axum::{
    extract::{Path, State},
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;
use serde::{Deserialize, Serialize};
use sqlx::types::Uuid;

use crate::{render_xml::RenderXml, AppState};

#[derive(Serialize)]
pub struct Teams {
    teams: Vec<Team>,
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

    RenderXml(key, state.engine, Teams { teams })
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct TeamsForm {
    speech_result: String,
}

pub async fn post_teams(
    State(state): State<AppState>,
    Form(form): Form<TeamsForm>,
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
        Redirect::to(&format!("/teams/{}", team.unwrap().id)).into_response()
    } else {
        RenderXml("/teams/not-found", state.engine, ()).into_response()
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

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct TeamForm {
    speech_result: String,
}

#[derive(sqlx::FromRow, Serialize)]
pub struct MeetingId {
    id: Uuid,
}

pub async fn post_team(
    State(state): State<AppState>,
    Path(id): Path<Uuid>,
    Form(form): Form<TeamForm>,
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
        RenderXml("/meetings/not-found", state.engine, id).into_response()
    }
}
