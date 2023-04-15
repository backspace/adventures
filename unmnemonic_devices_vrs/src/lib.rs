pub mod render_xml;
pub mod routes;

use axum::{
    routing::{get, post},
    Router,
};
use axum_template::engine::Engine;
use handlebars::Handlebars;
use sqlx::PgPool;

use crate::routes::*;

pub type AppEngine = Engine<Handlebars<'static>>;

#[derive(Clone)]
pub struct AppState {
    db: PgPool,
    engine: AppEngine,
}

pub async fn app(db: PgPool) -> Router {
    let mut hbs = Handlebars::new();
    hbs.register_templates_directory(".hbs", "src/templates")
        .expect("Failed to register templates directory");

    let shared_state = AppState {
        db,
        engine: Engine::from(hbs),
    };

    Router::new()
        .route("/", get(get_root))
        .route("/", post(post_root))
        .route("/teams", get(get_teams))
        .route("/teams", post(post_teams))
        .route("/teams/:id", get(get_team))
        .route("/teams/:id", post(post_team))
        .with_state(shared_state)
        .layer(tower_http::trace::TraceLayer::new_for_http())
}
