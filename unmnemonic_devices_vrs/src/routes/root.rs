use axum::{extract::Query, extract::State};
use serde::Deserialize;

use crate::AppState;

#[derive(Deserialize)]
pub struct RootParams {
    begun: Option<String>,
}

pub async fn root(State(state): State<AppState>, params: Query<RootParams>) -> &'static str {
    let settings = sqlx::query!("SELECT begun FROM settings LIMIT 1")
        .fetch_one(&state.db)
        .await
        .expect("Failed to fetch settings");

    if settings.begun.unwrap() || params.begun.is_some() {
        r#"BEGUN!!!"#
    } else {
        r#"<?xml version="1.0" encoding="UTF-8"?>
      <Response>
           <Say>Hello. Welcome to unmnemonic devices.</Say>
      </Response>"#
    }
}
