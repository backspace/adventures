use axum::{extract::State, response::IntoResponse};
use axum_template::Key;

use crate::{render_xml::RenderXml, AppState};

pub async fn get_hangup(Key(key): Key, State(state): State<AppState>) -> impl IntoResponse {
    RenderXml(key, state.engine, state.serialised_prompts, ())
}
