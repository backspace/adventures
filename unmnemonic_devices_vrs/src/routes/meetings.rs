use axum::{
    extract::{Path, State},
    response::IntoResponse,
};
use axum_template::Key;
use serde::Serialize;
use sqlx::types::Uuid;

use crate::{render_xml::RenderXml, AppState};

#[derive(sqlx::FromRow, Serialize)]
pub struct RegionAndDestination {
    name: String,
    description: String,
}

pub async fn get_meeting(
    Key(key): Key,
    Path(id): Path<Uuid>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let region_and_destination = sqlx::query_as::<_, RegionAndDestination>(
        r#"
          SELECT
            r.name, d.description
          FROM
              unmnemonic_devices.meetings m
          LEFT JOIN
              unmnemonic_devices.destinations d ON m.destination_id = d.id
          LEFT JOIN
              unmnemonic_devices.regions r ON d.region_id = r.id
          WHERE
              m.id = $1;
        "#,
    )
    .bind(id)
    .fetch_one(&state.db)
    .await
    .expect("Failed to fetch meeting");

    RenderXml(key, state.engine, region_and_destination)
}
