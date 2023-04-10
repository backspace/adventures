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
}

pub async fn get_teams(Key(key): Key, State(state): State<AppState>) -> impl IntoResponse {
    let teams = sqlx::query_as::<_, Team>("SELECT * FROM teams")
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

    let team = sqlx::query_as::<_, Team>("SELECT * FROM teams WHERE voicepass = $1")
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
    let team = sqlx::query_as::<_, Team>("SELECT * FROM teams WHERE id = $1")
        .bind(id)
        .fetch_one(&state.db)
        .await
        .expect("Failed to fetch team");

    RenderXml(key, state.engine, team)
}
