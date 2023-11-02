use axum::{
    extract::{Form, State},
    response::{IntoResponse, Response},
};
use axum_template::{Key, RenderHtml};
use serde::{Deserialize, Serialize};
use std::env;

use crate::auth::User;
use crate::config::{ConfigProvider, EnvVarProvider};
use crate::AppState;

#[derive(Serialize)]
pub struct Voicemails {
    voicemails: Vec<Voicemail>,
}

#[derive(sqlx::FromRow, Serialize)]
pub struct Voicemail {
    character_name: String,
    url: String,
    approved: Option<bool>,
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
            *
          FROM
            unmnemonic_devices.recordings
          WHERE
            type = 'voicemail'
          ORDER BY
            approved ASC, created_at
      "#,
    )
    .fetch_all(&state.db)
    .await
    .expect("Failed to fetch voicemails");

    RenderHtml(
        key.chars().skip(1).collect::<String>(),
        state.engine,
        Voicemails { voicemails },
    )
}
