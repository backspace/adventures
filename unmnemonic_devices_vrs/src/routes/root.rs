use axum::{
    extract::Query,
    extract::State,
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;
use serde::{Deserialize, Serialize};

use crate::{render_xml::RenderXml, twilio_form::TwilioForm, AppState};

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
}

#[axum_macros::debug_handler]
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
        state.serialised_prompts,
        RootData {
            begun: settings.begun.unwrap() || params.begun.is_some(),
            down: settings.down.unwrap(),
            ending: settings.ending.unwrap(),
        },
    )
}

#[axum_macros::debug_handler]
pub async fn post_root(Form(form): Form<TwilioForm>) -> Redirect {
    if form.speech_result == "Begun." {
        Redirect::to("/?begun")
    } else {
        Redirect::to("/")
    }
}
