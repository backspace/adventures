use crate::helpers::spawn_app;
use select::{document::Document, predicate::Name};
use speculoos::prelude::*;
use sqlx::PgPool;

#[sqlx::test(fixtures("schema"))]
async fn get_character_prompts_gathers_by_prompt_key(db: PgPool) {
    let app_address = spawn_app(db).await.address;

    let client = reqwest::Client::new();

    let response = client
        .get(&format!("{}/recordings/prompts/pure", &app_address))
        .send()
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text())
        .contains("Recording prompts for pure");

    let gather_hints = &document
        .find(Name("gather"))
        .next()
        .unwrap()
        .attr("hints")
        .unwrap();

    // Keys are unsorted
    assert_that(gather_hints).contains("voicepass");
    assert_that(gather_hints).contains("welcome");
}

#[sqlx::test(fixtures("schema"))]
async fn get_character_prompts_404s_for_unknown_character(db: PgPool) {
    let app_address = spawn_app(db).await.address;

    let client = reqwest::Client::new();

    let response = client
        .get(&format!("{}/recordings/prompts/who", &app_address))
        .send()
        .await
        .expect("Failed to execute request.");

    assert_eq!(response.status(), http::StatusCode::NOT_FOUND);
}
