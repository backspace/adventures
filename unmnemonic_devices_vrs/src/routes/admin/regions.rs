use axum::{extract::State, response::IntoResponse};
use axum_template::{Key, RenderHtml};
use serde::Serialize;
use sqlx::types::Uuid;

use crate::auth::User;
use crate::AppState;

#[derive(Debug, Serialize)]
pub struct Regions {
    regions: Vec<Region>,
}

#[derive(Debug, sqlx::FromRow, Serialize)]
pub struct Region {
    id: Uuid,
    synthetic_id: i64,
    name: String,
    url: Option<String>,
}

#[axum_macros::debug_handler]
pub async fn get_admin_regions(
    Key(key): Key,
    State(state): State<AppState>,
    _user: User,
) -> impl IntoResponse {
    let regions = sqlx::query_as::<_, Region>(
        r#"
          SELECT
            reg.id,
            reg.name,
            ROW_NUMBER() OVER (ORDER BY reg.created_at ASC) AS synthetic_id,
            rec.url
          FROM unmnemonic_devices.regions reg
          LEFT JOIN
              unmnemonic_devices.recordings rec ON reg.id = rec.region_id
          ORDER BY reg.created_at
        "#,
    )
    .fetch_all(&state.db)
    .await
    .expect("Failed to fetch regions");

    RenderHtml(
        key.chars().skip(1).collect::<String>(),
        state.engine,
        Regions { regions },
    )
}
