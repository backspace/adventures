use axum::{
    body::{Bytes, Full},
    extract::{Path, State},
    response::Response,
};

use crate::AppState;

pub async fn get_team(Path(id): Path<i32>, State(state): State<AppState>) -> Response<Full<Bytes>> {
    let row: (String,) = sqlx::query_as("SELECT name FROM teams WHERE id = $1")
        .bind(id)
        .fetch_one(&state.db)
        .await
        .expect("Failed to fetch team");

    let body = format!("<Response><Say>Welcome, team {}</Say></Response>", row.0);

    Response::builder()
        .header("content-type", "application/xml")
        .body(Full::from(body))
        .unwrap()
}
