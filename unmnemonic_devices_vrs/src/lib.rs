pub mod render_xml;
pub mod routes;
pub mod twilio_form;

use axum::{
    routing::{get, post},
    Router,
};
use axum_template::engine::Engine;
use handlebars::Handlebars;
use serde::Deserialize;
use sqlx::PgPool;
use std::{collections::HashMap, fs};

use crate::routes::*;

pub type AppEngine = Engine<Handlebars<'static>>;

#[derive(Clone)]
pub struct AppState {
    db: PgPool,
    engine: AppEngine,
    prompts: Prompts,
}

#[derive(Clone, Deserialize)]
struct Prompts {
    #[serde(flatten)]
    tables: HashMap<String, HashMap<String, String>>,
}

pub async fn app(db: PgPool) -> Router {
    let mut hbs = Handlebars::new();
    hbs.register_templates_directory(".hbs", "src/templates")
        .expect("Failed to register templates directory");

    let prompts_string =
        fs::read_to_string("src/prompts.toml").expect("Failed to read the prompts file");

    let prompts: Prompts =
        toml::from_str(&prompts_string).expect("Failed to parse the prompts file");

    let shared_state = AppState {
        db,
        engine: Engine::from(hbs),
        prompts,
    };

    Router::new()
        .route("/", get(get_root))
        .route("/", post(post_root))
        .route("/meetings/:id", get(get_meeting))
        .route(
            "/recordings/prompts/:character_name",
            get(get_character_prompts),
        )
        .route(
            "/recordings/prompts/:character_name",
            post(post_character_prompts),
        )
        .route(
            "/recordings/prompts/:character_name/:prompt_name",
            get(get_character_prompt),
        )
        .route(
            "/recordings/prompts/:character_name/:prompt_name",
            post(post_character_prompt),
        )
        .route(
            "/recordings/prompts/:character_name/:prompt_name/decide",
            post(post_character_prompt_decide),
        )
        .route("/teams", get(get_teams))
        .route("/teams", post(post_teams))
        .route("/teams/:id", get(get_team))
        .route("/teams/:id", post(post_team))
        .with_state(shared_state)
        .layer(tower_http::trace::TraceLayer::new_for_http())
}
