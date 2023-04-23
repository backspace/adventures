use axum::{extract::State, response::IntoResponse};
use axum_template::Key;
use serde::Serialize;
use std::collections::HashMap;

use crate::{helpers::get_prompts, render_xml::RenderXml, AppState};

#[derive(Serialize)]
pub struct HangupTemplate {
    prompts: HashMap<String, String>,
}

pub async fn get_hangup(Key(key): Key, State(state): State<AppState>) -> impl IntoResponse {
    RenderXml(
        key,
        state.engine,
        HangupTemplate {
            prompts: get_prompts(&["pure.goodybe"], state.db, state.prompts)
                .await
                .expect("Unable to get prompts"),
        },
    )
}
