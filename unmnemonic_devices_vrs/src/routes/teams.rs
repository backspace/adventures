use axum::{
    extract::{Path, State},
    response::IntoResponse,
};
use axum_template::Key;
use serde::Serialize;

use crate::{render_xml::RenderXml, AppState};

#[derive(Serialize)]
pub struct Teams {
    teams: Vec<Team>,
}

#[derive(sqlx::FromRow, Serialize)]
pub struct Team {
    id: i32,
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

pub async fn get_team(
    Key(key): Key,
    Path(id): Path<i32>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let team = sqlx::query_as::<_, Team>("SELECT * FROM teams WHERE id = $1")
        .bind(id)
        .fetch_one(&state.db)
        .await
        .expect("Failed to fetch team");

    RenderXml(key, state.engine, team)
}
