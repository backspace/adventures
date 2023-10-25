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
use serde::Deserialize;
use sqlx::{PgPool, Row};
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
    serialised_prompts: String,
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

    let prompts_string =
        fs::read_to_string("src/prompts.toml").expect("Failed to read the prompts file");

    let prompts: Prompts =
        toml::from_str(&prompts_string).expect("Failed to parse the prompts file");

    let wrapped_prompts = get_all_prompts(&services.db, &prompts)
        .await
        .expect("could not load prompts from database");

    let shared_state = AppState {
        db: services.db,
        twilio_address: services.twilio_address,
        engine: Engine::from(hbs),
        prompts,
        serialised_prompts: (WrappedPrompts {
            prompts: wrapped_prompts,
        })
        .serialize_to_string(),
    };

    Router::new()
        .route("/", get(get_root))
        .route("/", post(post_root))
        .route("/conferences/:sid", get(get_conference))
        .route("/hangup", get(get_hangup))
        .route("/meetings/:id", get(get_meeting))
        .route("/meetings/:id", post(post_meeting))
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
        //
        // admin routes
        .route("/admin/calls", get(get_calls))
        .route("/admin/calls", post(post_calls))
        .with_state(shared_state)
        .layer(tower_http::trace::TraceLayer::new_for_http())
}

pub async fn get_all_prompts(
    db: &PgPool,
    prompts: &Prompts,
) -> Result<HashMap<String, String>, String> {
    let query = r#"
      SELECT character_name, prompt_name, url
      FROM unmnemonic_devices.recordings
      WHERE url IS NOT NULL
      "#;

    let rows = sqlx::query(query).fetch_all(db).await.unwrap();

    let mut results = HashMap::new();
    for row in rows {
        let character_name: String = row.get("character_name");
        let prompt_name: String = row.get("prompt_name");
        let url: String = row.get("url");

        let key = format!("{}.{}", character_name, prompt_name);
        let prompt_text = prompts
            .tables
            .get(&character_name)
            .unwrap()
            .get(&prompt_name);
        let value = format!("<!-- {:?} --><Play>{}</Play>", prompt_text, url);
        results.insert(key, value);
    }

    for (character, prompts) in &prompts.tables {
        for (prompt_name, value) in prompts {
            let key = format!("{}.{}", character, prompt_name);

            results.entry(key).or_insert_with(|| {
                format!(
                    "<!-- {:?} --><Say>{:?}</Say>",
                    prompt_name,
                    value.to_string()
                )
            });
        }
    }

    Ok(results)
}
