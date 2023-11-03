pub mod auth;
pub mod config;
pub mod helpers;
pub mod render_xml;
pub mod routes;
pub mod twilio_form;

use axum::{
    routing::{get, post},
    Router,
};
use axum_template::engine::Engine;
use handlebars::Handlebars;
use handlebars_concat::HandlebarsConcat;
use helpers::get_all_prompts;
use serde::Deserialize;
use sqlx::PgPool;
use std::sync::{Arc, Mutex};
use std::{collections::HashMap, fs};

use crate::routes::*;

pub type AppEngine = Engine<Handlebars<'static>>;

pub struct InjectableServices {
    pub db: PgPool,
    pub twilio_address: String,
}

pub struct WrappedPrompts {
    prompts: HashMap<String, String>,
}

pub trait WrappedPromptsSerialisation {
    fn serialize_to_string(&self) -> String;
    fn deserialize_from_string(data: &str) -> Self;
}

impl WrappedPromptsSerialisation for WrappedPrompts {
    fn serialize_to_string(&self) -> String {
        serde_json::to_string(&self.prompts).expect("Failed to serialize")
    }
    fn deserialize_from_string(data: &str) -> Self {
        let prompts: HashMap<String, String> =
            serde_json::from_str(data).expect("Failed to deserialize");
        WrappedPrompts { prompts }
    }
}

#[derive(Clone)]
pub struct AppState {
    db: PgPool,
    twilio_address: String,
    engine: AppEngine,
    prompts: Prompts,
    mutable_prompts: Arc<Mutex<String>>,
}

#[derive(Clone, Deserialize)]
pub struct Prompts {
    #[serde(flatten)]
    tables: HashMap<String, HashMap<String, String>>,
}

pub async fn app(services: InjectableServices) -> Router {
    let mut hbs = Handlebars::new();
    hbs.register_templates_directory(".hbs", "src/templates")
        .expect("Failed to register templates directory");
    hbs.register_helper("concat", Box::new(HandlebarsConcat));

    let prompts_string =
        fs::read_to_string("src/prompts.toml").expect("Failed to read the prompts file");

    let prompts: Prompts =
        toml::from_str(&prompts_string).expect("Failed to parse the prompts file");

    let serialised_prompts = get_all_prompts(&services.db, &prompts).await;

    let shared_state = AppState {
        db: services.db,
        twilio_address: services.twilio_address,
        engine: Engine::from(hbs),
        prompts,
        mutable_prompts: Arc::new(Mutex::new(serialised_prompts)),
    };

    Router::new()
        .route("/prerecord", get(get_prerecord))
        .route("/record", get(get_record))
        .route("/", get(get_root))
        .route("/", post(post_root))
        .route("/conferences/:sid", get(get_conference))
        .route("/hangup", get(get_hangup))
        .route("/meetings/:id", get(get_meeting))
        .route("/meetings/:id", post(post_meeting))
        .route("/recordings", get(get_recordings))
        .route("/recordings", post(post_recordings))
        .route("/recordings/prompts", get(get_prompts))
        .route("/recordings/prompts", post(post_prompts))
        .route(
            "/recordings/prompts/:character_name",
            get(get_character_prompts),
        )
        .route(
            "/recordings/prompts/:character_name",
            post(post_character_prompts),
        )
        .route(
            "/recordings/prompts/:character_name/unrecorded",
            get(get_unrecorded_character_prompt),
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
        .route("/teams/:id/confirm", get(get_confirm_team))
        .route("/teams/:id/confirm", post(post_confirm_team))
        .route("/teams/:id/complete", get(get_complete_team))
        .route("/teams/:id/complete", post(post_complete_team))
        .route("/voicemails/:character_name", get(get_character_voicemail))
        .route(
            "/voicemails/:character_name",
            post(post_character_voicemail),
        )
        //
        // admin routes
        .route("/admin/calls", get(get_calls))
        .route("/admin/calls", post(post_calls))
        .route("/admin/teams", get(get_admin_teams))
        .route("/admin/prompts", get(get_admin_prompts))
        .route("/admin/voicemails", get(get_admin_voicemails))
        .route("/admin/voicemails/:id", post(post_admin_voicemail))
        .with_state(shared_state)
        .layer(tower_http::trace::TraceLayer::new_for_http())
}
