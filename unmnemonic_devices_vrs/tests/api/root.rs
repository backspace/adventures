use crate::helpers::{get, post, RedirectTo};
use select::{document::Document, predicate::Name};
use speculoos::prelude::*;
use sqlx::PgPool;

#[sqlx::test(fixtures("schema", "settings"))]
async fn root_serves_prewelcome(db: PgPool) {
    let response = get(db, "/", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");
    assert_that(&response.text().await.unwrap()).contains("unmnemonic");
}

#[sqlx::test(fixtures("schema", "settings", "recordings-prompts-pure-monitoring"))]
async fn root_serves_synthetic_disclaimer_when_no_recording(db: PgPool) {
    let response = get(db, "/", false)
        .await
        .expect("Failed to execute request.");

    let document = Document::from(response.text().await.unwrap().as_str());
    assert_that(&document.find(Name("play")).next().unwrap().text())
        .contains("http://example.com/monitoring");
}

#[sqlx::test(fixtures("schema", "settings"))]
async fn root_serves_recorded_disclaimer_when_it_exists(db: PgPool) {
    let response = get(db, "/", false)
        .await
        .expect("Failed to execute request.");

    let document = Document::from(response.text().await.unwrap().as_str());
    assert_that(&document.find(Name("say")).next().unwrap().text()).contains("quality assurance");
}

#[sqlx::test(fixtures("schema", "settings-begun"))]
async fn root_serves_welcome_when_begun(db: PgPool) {
    let response = get(db, "/", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");
    assert_that(&response.text().await.unwrap()).contains("Has it begun");
}

#[sqlx::test(fixtures("schema", "settings"))]
async fn root_serves_welcome_when_query_param_begin(db: PgPool) {
    let response = get(db, "/?begun", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");
    assert_that(&response.text().await.unwrap()).contains("Has it begun");
}

#[sqlx::test(fixtures("schema", "settings-ending"))]
async fn root_serves_ending_when_ending(db: PgPool) {
    let response = get(db, "/", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");
    assert_that(&response.text().await.unwrap()).contains("It is ending");
}

#[sqlx::test(fixtures("schema", "settings-down"))]
async fn root_serves_down_when_down(db: PgPool) {
    let response = get(db, "/", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");
    assert_that(&response.text().await.unwrap()).contains("It is down");
}

#[sqlx::test(fixtures("schema"))]
async fn root_post_begun_redirects_to_root_begun(db: PgPool) {
    let body = "SpeechResult=Begun.";

    let response = post(db, "/", body, true)
        .await
        .expect("Failed to execute response");
    assert_that(&response).redirects_to("/?begun");
}

#[sqlx::test(fixtures("schema"))]
async fn root_post_else_redirects_to_root(db: PgPool) {
    let body = "SpeechResult=whatever";

    let response = post(db, "/", body, true)
        .await
        .expect("Failed to execute response");
    assert_that(&response).redirects_to("/");
}
