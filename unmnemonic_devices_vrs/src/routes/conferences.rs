use axum::{
    extract::{Path, State},
    response::IntoResponse,
};
use axum_template::Key;
use serde::Serialize;

use crate::render_xml::RenderXml;
use crate::AppState;

#[derive(Serialize)]
pub struct Conference {
    sid: String,
}

#[axum_macros::debug_handler]
pub async fn get_conference(
    Key(key): Key,
    Path(sid): Path<String>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    RenderXml(
        key,
        state.engine,
        state.serialised_prompts,
        Conference { sid },
    )
}
