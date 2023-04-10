use axum::{
    extract::{Path, State},
    response::IntoResponse,
};
use axum_template::Key;
use serde::Serialize;

use crate::{render_xml::RenderXml, AppState};

#[derive(Serialize)]
pub struct Team {
    name: String,
}

pub async fn get_team(
    Key(key): Key,
    Path(id): Path<i32>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let row: (String,) = sqlx::query_as("SELECT name FROM teams WHERE id = $1")
        .bind(id)
        .fetch_one(&state.db)
        .await
        .expect("Failed to fetch team");

    RenderXml(key, state.engine, Team { name: row.0 })
}
