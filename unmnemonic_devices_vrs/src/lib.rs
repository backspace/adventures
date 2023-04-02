pub mod routes;

use axum::{routing::get, Router};
use sqlx::PgPool;

use crate::routes::root;

#[derive(Clone)]
pub struct AppState {
    db: PgPool,
}

pub async fn app(db: PgPool) -> Router {
    let shared_state = AppState { db };

    Router::new().route("/", get(root)).with_state(shared_state)
}
