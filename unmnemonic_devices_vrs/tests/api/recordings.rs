use crate::helpers::spawn_app;
use select::{document::Document, predicate::Name};
use serde::Serialize;
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

#[sqlx::test(fixtures("schema", "teams"))]
async fn post_character_prompts_redirects_to_prompt_path(db: PgPool) {
    let app_address = spawn_app(db).await.address;

    let client = reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::none())
        .build()
        .expect("Failed to construct request client");

    // Twilio editorialises punctuation and always capitalises.
    let body = "SpeechResult=Voicepass.";

    let response = client
        .post(&format!("{}/recordings/prompts/pure", &app_address))
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(body)
        .send()
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_redirection());
    assert_eq!(
        response
            .headers()
            .get("Location")
            .expect("Failed to extract Location header")
            .to_str()
            .unwrap(),
        "/recordings/prompts/pure/voicepass"
    );
}

#[sqlx::test(fixtures("schema", "teams"))]
async fn post_character_prompts_redirects_to_get_character_prompts_when_unknown(db: PgPool) {
    let app_address = spawn_app(db).await.address;

    let client = reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::none())
        .build()
        .expect("Failed to construct request client");

    let body = "SpeechResult=Prompty.";

    let response = client
        .post(&format!("{}/recordings/prompts/pure", &app_address))
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(body)
        .send()
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text())
        .contains("Could not find a prompt for pure called prompty");

    let redirect = document.find(Name("redirect")).next().unwrap();

    assert_that(&redirect.text()).contains("/recordings/prompts/pure");
    assert_eq!(redirect.attr("method").unwrap(), "GET");
}

#[sqlx::test(fixtures("schema"))]
async fn get_character_prompt_sets_up_recording(db: PgPool) {
    let app_address = spawn_app(db).await.address;

    let client = reqwest::Client::new();

    let response = client
        .get(&format!(
            "{}/recordings/prompts/pure/voicepass",
            &app_address
        ))
        .send()
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text())
        .contains("Recording voicepass prompt");

    let record_element = &document.find(Name("record")).next().unwrap();

    assert_eq!(
        record_element.attr("action").unwrap(),
        "/recordings/prompts/pure/voicepass"
    );
}

#[sqlx::test(fixtures("schema"))]
async fn get_character_prompt_redirects_to_prompts_path_for_unknown_prompt(db: PgPool) {
    let app_address = spawn_app(db).await.address;

    let client = reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::none())
        .build()
        .expect("Failed to construct request client");

    let response = client
        .get(&format!("{}/recordings/prompts/pure/what", &app_address))
        .send()
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_redirection());
    assert_eq!(
        response
            .headers()
            .get("Location")
            .expect("Failed to extract Location header")
            .to_str()
            .unwrap(),
        "/recordings/prompts/pure"
    );
}

#[sqlx::test(fixtures("schema"))]
async fn post_character_prompt_plays_recording_and_gathers_decision(db: PgPool) {
    let app_address = spawn_app(db.clone()).await.address;

    let client = reqwest::Client::new();

    let body = "RecordingUrl=http://example.com/voicepass";

    let response = client
        .post(&format!(
            "{}/recordings/prompts/pure/voicepass",
            &app_address
        ))
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(body)
        .send()
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_eq!(
        &document.find(Name("play")).next().unwrap().text(),
        "http://example.com/voicepass"
    );

    assert_eq!(
        &document
            .find(Name("gather"))
            .next()
            .unwrap()
            .attr("action")
            .unwrap(),
        &"/recordings/prompts/pure/voicepass/decide?recording_url=http%3A%2F%2Fexample.com%2Fvoicepass"
    );
}

#[derive(sqlx::FromRow, Serialize)]
pub struct RecordingUrl {
    url: String,
}

#[sqlx::test(fixtures("schema"))]
async fn post_character_prompt_decide_stores_recording_upon_keep(db: PgPool) {
    let app_address = spawn_app(db.clone()).await.address;

    let client = reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::none())
        .build()
        .expect("Failed to construct request client");

    let body = "SpeechResult=Keep.";

    let response = client
        .post(&format!(
            "{}/recordings/prompts/pure/voicepass/decide?recording_url=http://example.com/newvoicepass",
            &app_address
        ))
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(body)
        .send()
        .await
        .expect("Failed to execute request.");

    let recording_url = sqlx::query_as::<_, RecordingUrl>(
        r#"
          SELECT
            r.url
          FROM
            unmnemonic_devices.recordings r
          WHERE
            r.character_name = $1
            AND r.prompt_name = $2
        "#,
    )
    .bind("pure")
    .bind("voicepass")
    .fetch_one(&db)
    .await;

    assert_eq!(
        recording_url.unwrap().url,
        "http://example.com/newvoicepass"
    );

    assert!(response.status().is_redirection());
    assert_eq!(
        response
            .headers()
            .get("Location")
            .expect("Failed to extract Location header")
            .to_str()
            .unwrap(),
        "/recordings/prompts/pure"
    );
}

#[sqlx::test(fixtures("schema", "recordings-prompts-pure-voicepass"))]
async fn post_character_prompt_decide_updates_recording_upon_keep(db: PgPool) {
    let app_address = spawn_app(db.clone()).await.address;

    let client = reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::none())
        .build()
        .expect("Failed to construct request client");

    let body = "SpeechResult=Keep.";

    let response = client
        .post(&format!(
            "{}/recordings/prompts/pure/voicepass/decide?recording_url=http://example.com/newervoicepass",
            &app_address
        ))
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(body)
        .send()
        .await
        .expect("Failed to execute request.");

    let recording_url = sqlx::query_as::<_, RecordingUrl>(
        r#"
          SELECT
            r.url
          FROM
            unmnemonic_devices.recordings r
          WHERE
            r.character_name = $1
            AND r.prompt_name = $2
        "#,
    )
    .bind("pure")
    .bind("voicepass")
    .fetch_one(&db)
    .await;

    assert_eq!(
        recording_url.unwrap().url,
        "http://example.com/newervoicepass"
    );

    assert!(response.status().is_redirection());
    assert_eq!(
        response
            .headers()
            .get("Location")
            .expect("Failed to extract Location header")
            .to_str()
            .unwrap(),
        "/recordings/prompts/pure"
    );
}

#[sqlx::test(fixtures("schema", "recordings-prompts-pure-voicepass"))]
async fn post_character_prompt_decide_discards_upon_rerecord(db: PgPool) {
    let app_address = spawn_app(db.clone()).await.address;

    let client = reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::none())
        .build()
        .expect("Failed to construct request client");

    let body = "SpeechResult=Rerecord.";

    let response = client
        .post(&format!(
            "{}/recordings/prompts/pure/voicepass/decide?recording_url=http://example.com/newervoicepass",
            &app_address
        ))
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(body)
        .send()
        .await
        .expect("Failed to execute request.");

    let recording_url = sqlx::query_as::<_, RecordingUrl>(
        r#"
          SELECT
            r.url
          FROM
            unmnemonic_devices.recordings r
          WHERE
            r.character_name = $1
            AND r.prompt_name = $2
        "#,
    )
    .bind("pure")
    .bind("voicepass")
    .fetch_one(&db)
    .await;

    assert_eq!(
        recording_url.unwrap().url,
        "http://example.com/old-voicepass"
    );

    assert!(response.status().is_redirection());
    assert_eq!(
        response
            .headers()
            .get("Location")
            .expect("Failed to extract Location header")
            .to_str()
            .unwrap(),
        "/recordings/prompts/pure/voicepass"
    );
}
