use axum::{extract::State, response::IntoResponse};
use axum_template::{Key, RenderHtml};
use serde::Serialize;
use sqlx::types::Uuid;
use std::collections::HashMap;
use uuid_for_readable::Uuid as OldUuid;
use uuid_readable_rs::short_from;

use crate::auth::User;
use crate::AppState;

#[derive(Debug, Serialize)]
pub struct Regions {
    regions: Vec<Region>,
    region_id_to_readable_id: HashMap<Uuid, String>,
}

#[derive(Debug, sqlx::FromRow, Serialize)]
pub struct Region {
    id: Uuid,
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
          SELECT reg.id, reg.name, rec.url
          FROM unmnemonic_devices.regions reg
          LEFT JOIN
              unmnemonic_devices.recordings rec ON reg.id = rec.region_id
          ORDER BY name
        "#,
    )
    .fetch_all(&state.db)
    .await
    .expect("Failed to fetch regions");

    let region_id_to_readable_id = regions
        .iter()
        .map(|region| {
            (
                region.id,
                short_from(OldUuid::from_bytes(region.id.into_bytes())),
            )
        })
        .collect();

    RenderHtml(
        key.chars().skip(1).collect::<String>(),
        state.engine,
        Regions {
            regions,
            region_id_to_readable_id,
        },
    )
}
