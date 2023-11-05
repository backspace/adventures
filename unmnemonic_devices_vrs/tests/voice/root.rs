mod helpers {
    include!("../helpers.rs");
}
use helpers::{get, post, RedirectTo};

use select::{
    document::Document,
    predicate::{Descendant, Name},
};
use serde::Serialize;
use speculoos::prelude::*;
use sqlx::PgPool;

#[derive(sqlx::FromRow, Serialize)]
pub struct CallRecord {
    id: String,
    number: String,
}

#[sqlx::test(fixtures("schema", "settings"))]
async fn root_serves_prewelcome_and_stores_call(db: PgPool) {
    let response = get(db.clone(), "/?CallSid=xyz&Caller=2040000000", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");
    assert_that(&response.text().await.unwrap()).contains("unmnemonic");

    let call = sqlx::query_as::<_, CallRecord>(
        r#"
      SELECT
        id, number
      FROM
        unmnemonic_devices.calls
      WHERE
        id = $1
    "#,
    )
    .bind("xyz")
    .fetch_one(&db)
    .await
    .unwrap();

    assert_eq!(call.id, "xyz");
    assert_eq!(call.number, "2040000000");
}

#[sqlx::test(fixtures("schema", "settings"))]
async fn root_ignores_duplicate_call_sid(db: PgPool) {
    let response = get(
        db.clone(),
        "/?CallSid=xyz&Caller=2040000000&CallSid=abc",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
}

#[sqlx::test(fixtures("schema", "settings"))]
async fn root_serves_synthetic_disclaimer_when_no_recording_and_hints_character_names(db: PgPool) {
    let response = get(db, "/", false)
        .await
        .expect("Failed to execute request.");

    let text = response.text().await.unwrap();
    let document = Document::from(text.as_str());

    assert_that(
        &document
            .find(Descendant(Name("gather"), Name("say")))
            .next()
            .unwrap()
            .text(),
    )
    .contains("welcome");

    let gather_hints = &document
        .find(Name("gather"))
        .next()
        .unwrap()
        .attr("hints")
        .unwrap();

    assert_that(gather_hints).contains("knut");
    assert_that(gather_hints).contains("pure");
    assert_that(gather_hints).contains("remember");
    assert_that(gather_hints).contains("testa");
    assert_that(gather_hints).contains("testb");
}

#[sqlx::test(fixtures("schema", "settings", "recordings-prompts-pure-welcome"))]
async fn root_serves_recorded_disclaimer_when_it_exists(db: PgPool) {
    let response = get(db, "/", false)
        .await
        .expect("Failed to execute request.");

    let text = response.text().await.unwrap();
    let document = Document::from(text.as_str());

    assert_that(
        &document
            .find(Descendant(Name("gather"), Name("play")))
            .next()
            .unwrap()
            .text(),
    )
    .contains("http://example.com/welcome");
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
async fn post_recordings_redirects(db: PgPool) {
    for (speech_result, redirect) in [
        ("Begun.", "/?begun"),
        ("Recordings.", "/recordings"),
        ("Knut.", "/voicemails/knut"),
        ("Pure.", "/voicemails/pure"),
        ("Remember.", "/voicemails/remember/confirm"),
        ("whatever.", "/"),
    ] {
        let response = post(
            db.clone(),
            "/",
            // Twilio editorialises punctuation and always capitalises.
            &format!("SpeechResult={}", speech_result),
            true,
        )
        .await
        .expect("Failed to execute request.");

        assert_that(&response).redirects_to(redirect);
    }
}
