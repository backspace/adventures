use axum::{routing::get, Router};

pub fn app() -> Router {
    Router::new().route("/", get(root))
}

async fn root() -> &'static str {
    r#"<?xml version="1.0" encoding="UTF-8"?>
  <Response>
       <Say>Hello. Welcome to unmnemonic devices.</Say>
  </Response>"#
}
