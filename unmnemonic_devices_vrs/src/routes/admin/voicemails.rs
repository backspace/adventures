use axum::{
    extract::{Form, Path, State},
    response::{IntoResponse, Response},
};
use axum_template::{Key, RenderHtml};
use http::StatusCode;
use serde::{Deserialize, Serialize};
use sqlx::types::Uuid;

use crate::auth::User;
use crate::AppState;

#[derive(Serialize)]
pub struct Voicemails {
    unapproved: Vec<Voicemail>,
    approved: Vec<Voicemail>,
    rejected: Vec<Voicemail>,
}

#[derive(Clone, sqlx::FromRow, Serialize)]
pub struct Voicemail {
    id: Uuid,
    character_name: String,
    url: String,
    approved: Option<bool>,
    team_name: Option<String>,
}

#[axum_macros::debug_handler]
pub async fn get_admin_voicemails(
    Key(key): Key,
    State(state): State<AppState>,
    _user: User,
) -> impl IntoResponse {
    let voicemails = sqlx::query_as::<_, Voicemail>(
        r#"
          SELECT
            r.*,
            t.name_truncated as team_name
          FROM
            unmnemonic_devices.recordings r
          LEFT JOIN
            unmnemonic_devices.calls c ON r.call_id = c.id
          LEFT JOIN
            public.teams t ON c.team_id = t.id
          WHERE
            type = 'voicemail'
          ORDER BY
            approved ASC, inserted_at
      "#,
    )
    .fetch_all(&state.db)
    .await
    .expect("Failed to fetch voicemails");

    let unapproved = voicemails
        .iter()
        .filter(|v| v.approved == Some(false))
        .cloned()
        .collect::<Vec<_>>();

    let approved = voicemails
        .iter()
        .filter(|v| v.approved == Some(true))
        .cloned()
        .collect::<Vec<_>>();

    let rejected = voicemails
        .iter()
        .filter(|v| v.approved.is_none())
        .cloned()
        .collect::<Vec<_>>();

    RenderHtml(
        key.chars().skip(1).collect::<String>(),
        state.engine,
        Voicemails {
            unapproved,
            approved,
            rejected,
        },
    )
}

#[derive(Deserialize)]
pub struct UpdateRecordingParams {
    approved: Option<bool>,
}

#[axum_macros::debug_handler]
pub async fn post_admin_voicemail(
    Path(id): Path<Uuid>,
    State(state): State<AppState>,
    Form(params): Form<UpdateRecordingParams>,
) -> Response {
    println!("approved? {:?}", params.approved);
    sqlx::query!(
        r#"
UPDATE
  unmnemonic_devices.recordings
SET
  approved = $1
WHERE
  id = $2;
"#,
        params.approved,
        id
    )
    .execute(&state.db)
    .await
    .ok();

    StatusCode::NO_CONTENT.into_response()
}
