use axum::{
    extract::Query,
    extract::State,
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;
use serde::{Deserialize, Serialize};

use crate::{render_xml::RenderXml, AppState};

#[derive(Deserialize)]
pub struct RootParams {
    begun: Option<String>,
}

#[derive(Serialize)]
struct Settings {
    begun: bool,
}

pub async fn get_root(
    Key(key): Key,
    State(state): State<AppState>,
    params: Query<RootParams>,
) -> impl IntoResponse {
    let settings = sqlx::query!("SELECT begun FROM unmnemonic_devices.settings LIMIT 1")
        .fetch_one(&state.db)
        .await
        .expect("Failed to fetch settings");

    RenderXml(
        key,
        state.engine,
        Settings {
            begun: settings.begun.unwrap() || params.begun.is_some(),
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
