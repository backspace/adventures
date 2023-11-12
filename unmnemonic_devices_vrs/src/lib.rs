pub mod auth;
pub mod config;
pub mod helpers;
pub mod render_xml;
pub mod routes;
pub mod twilio_form;

use axum::{
    body::Bytes,
    extract::MatchedPath,
    http::{HeaderMap, Request},
    middleware,
    response::Response,
    routing::{get, post},
    Router,
};
use axum_template::engine::Engine;
use handlebars::Handlebars;
use handlebars_concat::HandlebarsConcat;
use helpers::{get_all_prompts, store_call_path_middleware};
use serde::Deserialize;
use sqlx::PgPool;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use std::{collections::HashMap, fs};
use tower_http::{classify::ServerErrorsFailureClass, trace::TraceLayer};
use tracing::{info_span, Span};

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
        .route("/recordings/regions", get(get_recording_regions))
        .route("/recordings/regions", post(post_recording_regions))
        .route("/recordings/regions/unrecorded", get(get_unrecorded_region))
        .route("/recordings/regions/:id", get(get_recording_region))
        .route("/recordings/regions/:id", post(post_recording_region))
        .route(
            "/recordings/regions/:id/decide",
            post(post_recording_region_decide),
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
        .route(
            "/voicemails/remember/confirm",
            get(get_voicemails_remember_confirm),
        )
        .route(
            "/voicemails/remember/confirm",
            post(post_voicemails_remember_confirm),
        )
        .layer(middleware::from_fn_with_state(
            shared_state.clone(),
            store_call_path_middleware,
        ))
        //
        // admin routes
        .route("/admin/calls", get(get_calls))
        .route("/admin/calls", post(post_calls))
        .route("/admin/regions", get(get_admin_regions))
        .route("/admin/teams", get(get_admin_teams))
        .route("/admin/prompts", get(get_admin_prompts))
        .route("/admin/voicemails", get(get_admin_voicemails))
        .route("/admin/voicemails/:id", post(post_admin_voicemail))
        .with_state(shared_state)
        .layer(
            TraceLayer::new_for_http()
                .make_span_with(|request: &Request<_>| {
                    // Log the matched route's path (with placeholders not filled in).
                    // Use request.uri() or OriginalUri if you want the real path.
                    let matched_path = request
                        .extensions()
                        .get::<MatchedPath>()
                        .map(MatchedPath::as_str);

                    info_span!(
                        "http_request",
                        method = ?request.method(),
                        matched_path,
                        some_other_field = tracing::field::Empty,
                    )
                })
                .on_request(|_request: &Request<_>, _span: &Span| {
                    // You can use `_span.record("some_other_field", value)` in one of these
                    // closures to attach a value to the initially empty field in the info_span
                    // created above.
                })
                .on_response(|_response: &Response, _latency: Duration, _span: &Span| {
                    // ...
                })
                .on_body_chunk(|_chunk: &Bytes, _latency: Duration, _span: &Span| {
                    // ...
                })
                .on_eos(
                    |_trailers: Option<&HeaderMap>, _stream_duration: Duration, _span: &Span| {
                        // ...
                    },
                )
                .on_failure(
                    |_error: ServerErrorsFailureClass, _latency: Duration, _span: &Span| {
                        // ...
                    },
                ),
        )
        .layer(tower_http::trace::TraceLayer::new_for_http())
}
