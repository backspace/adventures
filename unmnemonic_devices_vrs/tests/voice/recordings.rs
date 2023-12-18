use crate::common;
use common::helpers::{get, get_config, post, RedirectTo};
use select::{document::Document, predicate::Name};

use speculoos::prelude::*;
use sqlx::PgPool;

#[sqlx::test(fixtures("schema", "settings-down"))]
async fn root_serves_down_when_down(db: PgPool) {
    let config = get_config();
    let recordings_voicepass = config.recordings_voicepass.to_string();

    let response = get(db, "/recordings/confirm", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());

    let text = response.text().await.unwrap();
    let document = Document::from(text.as_str());

    let gather_hints = &document
        .find(Name("gather"))
        .next()
        .unwrap()
        .attr("hints")
        .unwrap();

    assert_that(gather_hints).contains(recordings_voicepass);
}

#[sqlx::test(fixtures("schema"))]
async fn post_recordings_confirm_redirects(db: PgPool) {
    let config = get_config();
    let recordings_voicepass = config.recordings_voicepass.to_string();

    for (speech_result, redirect) in [
        (format!("{}.", recordings_voicepass), "/recordings"),
        ("Whatttt.".to_string(), "/recordings/voicepass-incorrect"),
    ] {
        let response = post(
            db.clone(),
            "/recordings/confirm",
            // Twilio editorialises punctuation and always capitalises.
            &format!("SpeechResult={}", speech_result),
            true,
        )
        .await
        .expect("Failed to execute request.");

        assert_that(&response).redirects_to(redirect);
    }
}

#[sqlx::test(fixtures("schema", "teams"))]
async fn post_recordings_redirects(db: PgPool) {
    for (speech_result, redirect) in [
        ("Prompts.", "/recordings/prompts"),
        ("Destinations.", "/recordings/destinations"),
        ("Regions.", "/recordings/regions"),
        ("Teams.", "/recordings/teams"),
    ] {
        let response = post(
            db.clone(),
            "/recordings",
            // Twilio editorialises punctuation and always capitalises.
            &format!("SpeechResult={}", speech_result),
            true,
        )
        .await
        .expect("Failed to execute request.");

        assert_that(&response).redirects_to(redirect);
    }
}
