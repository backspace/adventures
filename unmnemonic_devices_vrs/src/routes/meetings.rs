use axum::{
    extract::{Path, State},
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;
use serde::Serialize;
use sqlx::types::Uuid;

use crate::{render_xml::RenderXml, twilio_form::TwilioForm, AppState};

#[derive(sqlx::FromRow, Serialize)]
pub struct RegionAndDestination {
    name: String,
    description: String,
}

#[derive(Serialize)]
pub struct MeetingTemplate {
    name: String,
    description: String,
}

#[axum_macros::debug_handler]
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

    sqlx::query!(
        r#"
      UPDATE
        unmnemonic_devices.meetings
      SET
        listens = listens + 1
      WHERE
        id = $1;
    "#,
        id
    )
    .execute(&state.db)
    .await
    .ok();

    RenderXml(
        key,
        state.engine,
        state.serialised_prompts,
        MeetingTemplate {
            name: region_and_destination.name,
            description: region_and_destination.description,
        },
    )
}

#[axum_macros::debug_handler]
pub async fn post_meeting(Path(id): Path<Uuid>, Form(form): Form<TwilioForm>) -> Redirect {
    match form.speech_result.as_str() {
        "Record." => Redirect::to("/voicemails/fixme"),
        "End." => Redirect::to("/hangup"),
        _ => Redirect::to(&format!("/meetings/{}", id)),
    }
}
