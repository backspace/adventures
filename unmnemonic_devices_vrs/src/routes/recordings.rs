use axum::{
    extract::{Path, State},
    response::IntoResponse,
};
use axum_template::Key;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;

use crate::{render_xml::RenderXml, AppState};

#[derive(Debug, Deserialize)]
struct Config {
    #[serde(flatten)]
    tables: HashMap<String, HashMap<String, String>>,
}

#[derive(Serialize)]
pub struct CharacterPrompts {
    character_name: String,
    prompt_names: Option<Vec<String>>,
}

pub async fn get_character_prompts(
    Key(key): Key,
    Path(character_name): Path<String>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let content = fs::read_to_string("src/prompts.toml").expect("Failed to read the prompts file");

    let config: Config = toml::from_str(&content).expect("Failed to parse the prompts file");

    let character_prompts = config.tables.get(&character_name);

    if character_prompts.is_some() {
        RenderXml(
            key,
            state.engine,
            CharacterPrompts {
                character_name,
                prompt_names: Some(character_prompts.unwrap().keys().cloned().collect()),
            },
        )
        .into_response()
    } else {
        (http::StatusCode::NOT_FOUND, "character not found").into_response()
    }
}
