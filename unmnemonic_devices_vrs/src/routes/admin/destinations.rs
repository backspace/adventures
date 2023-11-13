use axum::{extract::State, response::IntoResponse};
use axum_template::{Key, RenderHtml};
use serde::Serialize;
use sqlx::types::Uuid;

use crate::auth::User;
use crate::AppState;

#[derive(Debug, Serialize)]
pub struct Destinations {
    destinations: Vec<Destination>,
}

#[derive(Debug, sqlx::FromRow, Serialize)]
pub struct Destination {
    id: Uuid,
    synthetic_id: i64,
    description: String,
    url: Option<String>,
}

#[axum_macros::debug_handler]
pub async fn get_admin_destinations(
    Key(key): Key,
    State(state): State<AppState>,
    _user: User,
) -> impl IntoResponse {
    let destinations = sqlx::query_as::<_, Destination>(
        r#"
          SELECT
            d.id,
            d.description,
            ROW_NUMBER() OVER (ORDER BY d.created_at ASC) AS synthetic_id,
            rec.url
          FROM unmnemonic_devices.destinations d
          LEFT JOIN
              unmnemonic_devices.recordings rec ON d.id = rec.destination_id
          ORDER BY d.created_at
        "#,
    )
    .fetch_all(&state.db)
    .await
    .expect("Failed to fetch destinations");

    RenderHtml(
        key.chars().skip(1).collect::<String>(),
        state.engine,
        Destinations { destinations },
    )
}
