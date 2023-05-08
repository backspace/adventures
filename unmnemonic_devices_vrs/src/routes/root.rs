use axum::{
    extract::Query,
    extract::State,
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

use crate::{helpers::get_prompts, render_xml::RenderXml, AppState};

#[derive(Deserialize)]
pub struct RootParams {
    begun: Option<String>,
}

#[derive(Serialize)]
struct Settings {
    begun: bool,
}

#[derive(Serialize)]
pub struct RootData {
    begun: bool,
    down: bool,
    ending: bool,
    prompts: HashMap<String, String>,
}

pub async fn get_root(
    Key(key): Key,
    State(state): State<AppState>,
    params: Query<RootParams>,
) -> impl IntoResponse {
    let settings =
        sqlx::query!("SELECT begun, down, ending FROM unmnemonic_devices.settings LIMIT 1")
            .fetch_one(&state.db)
            .await
            .expect("Failed to fetch settings");

    RenderXml(
        key,
        state.engine,
        RootData {
            begun: settings.begun.unwrap() || params.begun.is_some(),
            down: settings.down.unwrap(),
            ending: settings.ending.unwrap(),
            prompts: get_prompts(
                &["pure.welcome", "pure.monitoring"],
                state.db,
                state.prompts,
            )
            .await
            .expect("Unable to get prompts"),
        },
    )
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct RootForm {
    speech_result: String,
}

pub async fn post_root(Form(form): Form<RootForm>) -> Redirect {
    if form.speech_result == "Begun." {
        Redirect::to("/?begun")
    } else {
        Redirect::to("/")
    }
}
