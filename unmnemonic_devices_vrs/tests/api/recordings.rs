use crate::helpers::{get, post, RedirectTo};
use select::{document::Document, predicate::Name};
use serde::Serialize;
use speculoos::prelude::*;
use sqlx::PgPool;

#[sqlx::test(fixtures("schema"))]
async fn get_character_prompts_gathers_by_prompt_key(db: PgPool) {
    let response = get(db, "/recordings/prompts/testa", false)
        .await
        .expect("Failed to execute request");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text())
        .contains("Recording prompts for testa");

    assert_that(&document.find(Name("gather")).next().unwrap().text())
        .contains("Or say unrecorded prompts.");

    let gather_hints = &document
        .find(Name("gather"))
        .next()
        .unwrap()
        .attr("hints")
        .unwrap();

    // Keys are unsorted
    assert_that(gather_hints).contains("voicepass");
    assert_that(gather_hints).contains("welcome");
    assert_that(gather_hints).contains("unrecorded prompts");
}

#[sqlx::test(fixtures("schema", "recordings-prompts-testb-welcome"))]
async fn get_character_prompts_gathers_by_prompt_key_without_unrecorded_when_no_unrecorded(
    db: PgPool,
) {
    let response = get(db, "/recordings/prompts/testb", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text())
        .does_not_contain("Recording prompts for testa");

    let gather_hints = &document
        .find(Name("gather"))
        .next()
        .unwrap()
        .attr("hints")
        .unwrap();

    assert_that(gather_hints).does_not_contain("unrecorded prompts");
}

#[sqlx::test(fixtures("schema"))]
async fn get_character_prompts_404s_for_unknown_character(db: PgPool) {
    let response = get(db, "/recordings/prompts/who", false)
        .await
        .expect("Failed to execute request.");

    assert_eq!(response.status(), http::StatusCode::NOT_FOUND);
}

#[sqlx::test(fixtures("schema", "teams"))]
async fn post_character_prompts_redirects_to_prompt_path(db: PgPool) {
    let response = post(
        db,
        "/recordings/prompts/testa",
        // Twilio editorialises punctuation and always capitalises.
        "SpeechResult=Voicepass.",
        true,
    )
    .await
    .expect("Failed to execute request.");

    assert_that(&response).redirects_to("/recordings/prompts/testa/voicepass");
}

#[sqlx::test(fixtures(
    "schema",
    "recordings-prompts-testa-voicepass",
    "recordings-prompts-testb-welcome"
))]
async fn post_character_prompts_with_unrecorded_redirects_to_unrecorded_path(db: PgPool) {
    let body = "SpeechResult=Unrecorded prompts.";

    let response = post(db, "/recordings/prompts/testa", body, true)
        .await
        .expect("Failed to execute request.");

    assert_that(&response).redirects_to("/recordings/prompts/testa/unrecorded");
}

#[sqlx::test(fixtures(
    "schema",
    "recordings-prompts-testa-voicepass",
    "recordings-prompts-testb-welcome"
))]
async fn get_character_prompts_unrecorded_redirects_to_first_unrecorded_prompt_path(db: PgPool) {
    let response = get(db, "/recordings/prompts/testa/unrecorded", true)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text())
        .contains("Will cycle through unrecorded prompts for testa");

    let redirect = document.find(Name("redirect")).next().unwrap();

    assert_that(&redirect.text()).contains("/recordings/prompts/testa/welcome?unrecorded");
    assert_eq!(redirect.attr("method").unwrap(), "GET");
}

#[sqlx::test(fixtures(
    "schema",
    "recordings-prompts-testa-voicepass",
    "recordings-prompts-testb-welcome"
))]
async fn get_character_prompts_unrecorded_skips_message_with_unrecorded_param(db: PgPool) {
    let response = get(db, "/recordings/prompts/testa/unrecorded?unrecorded", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("response")).next().unwrap().text())
        .does_not_contain("cycle through unrecorded");
}

#[sqlx::test(fixtures(
    "schema",
    "recordings-prompts-testa-voicepass",
    "recordings-prompts-testb-welcome"
))]
async fn get_character_prompts_unrecorded_redirects_to_prompt_select_when_no_unrecorded(
    db: PgPool,
) {
    let response = get(db, "/recordings/prompts/testb/unrecorded", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text())
        .contains("All prompts for testb are recorded");

    let redirect = document.find(Name("redirect")).next().unwrap();

    assert_that(&redirect.text()).contains("/recordings/prompts/testb");
    assert_eq!(redirect.attr("method").unwrap(), "GET");
}

#[sqlx::test(fixtures("schema", "teams"))]
async fn post_character_prompts_redirects_to_get_character_prompts_when_unknown(db: PgPool) {
    let body = "SpeechResult=Prompty.";

    let response = post(db, "/recordings/prompts/testa", body, true)
        .await
        .expect("Failed to execute response");
    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text())
        .contains("Could not find a prompt for testa called prompty");

    let redirect = document.find(Name("redirect")).next().unwrap();

    assert_that(&redirect.text()).contains("/recordings/prompts/testa");
    assert_eq!(redirect.attr("method").unwrap(), "GET");
}

#[sqlx::test(fixtures("schema"))]
async fn get_character_prompt_sets_up_recording(db: PgPool) {
    let response = get(db, "/recordings/prompts/testa/voicepass", false)
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
        "/recordings/prompts/testa/voicepass"
    );
}

#[sqlx::test(fixtures("schema"))]
async fn get_character_prompt_forwards_unrecorded(db: PgPool) {
    let response = get(db, "/recordings/prompts/testa/voicepass?unrecorded", false)
        .await
        .expect("Failed to execute request.");

    let document = Document::from(response.text().await.unwrap().as_str());

    let record_element = &document.find(Name("record")).next().unwrap();

    assert_eq!(
        record_element.attr("action").unwrap(),
        "/recordings/prompts/testa/voicepass?unrecorded"
    );
}

#[sqlx::test(fixtures("schema"))]
async fn get_character_prompt_redirects_to_prompts_path_for_unknown_prompt(db: PgPool) {
    let response = get(db, "/recordings/prompts/testa/what", true)
        .await
        .expect("Failed to execute request.");

    assert_that(&response).redirects_to("/recordings/prompts/testa");
}

#[sqlx::test(fixtures("schema"))]
async fn post_character_prompt_plays_recording_and_gathers_decision(db: PgPool) {
    let response = post(
        db,
        "/recordings/prompts/testa/voicepass",
        "RecordingUrl=http://example.com/voicepass",
        false,
    )
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
        &"/recordings/prompts/testa/voicepass/decide?recording_url=http%3A%2F%2Fexample.com%2Fvoicepass"
    );
}

#[sqlx::test(fixtures("schema"))]
async fn post_character_prompt_forwards_unrecorded(db: PgPool) {
    let response = post(
        db,
        "/recordings/prompts/testa/voicepass?unrecorded",
        "RecordingUrl=http://example.com/voicepass",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(
        &document
            .find(Name("gather"))
            .next()
            .unwrap()
            .attr("action")
            .unwrap(),
    )
    .contains("unrecorded");
}

#[derive(sqlx::FromRow, Serialize)]
pub struct RecordingUrl {
    url: String,
}

#[sqlx::test(fixtures("schema"))]
async fn post_character_prompt_decide_stores_recording_upon_keep(db: PgPool) {
    let response = post(
        db.clone(),
        "/recordings/prompts/testa/voicepass/decide?recording_url=http://example.com/newvoicepass",
        "SpeechResult=Keep.",
        true,
    )
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
    .bind("testa")
    .bind("voicepass")
    .fetch_one(&db)
    .await;

    assert_eq!(
        recording_url.unwrap().url,
        "http://example.com/newvoicepass"
    );

    assert_that(&response).redirects_to("/recordings/prompts/testa");
}

#[sqlx::test(fixtures("schema"))]
async fn post_character_prompt_decide_forwards_unrecorded(db: PgPool) {
    let response = post(db, "/recordings/prompts/testa/voicepass/decide?recording_url=http://example.com/newvoicepass&unrecorded", "SpeechResult=Keep.", true)        .await
        .expect("Failed to execute request.");

    assert_that(&response).redirects_to("/recordings/prompts/testa/unrecorded?unrecorded");
}

#[sqlx::test(fixtures("schema", "recordings-prompts-testa-voicepass"))]
async fn post_character_prompt_decide_updates_recording_upon_keep(db: PgPool) {
    let response = post(db.clone(), "/recordings/prompts/testa/voicepass/decide?recording_url=http://example.com/newervoicepass", "SpeechResult=Keep.", true)        .await
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
    .bind("testa")
    .bind("voicepass")
    .fetch_one(&db)
    .await;

    assert_eq!(
        recording_url.unwrap().url,
        "http://example.com/newervoicepass"
    );

    assert_that(&response).redirects_to("/recordings/prompts/testa");
}

#[sqlx::test(fixtures("schema", "recordings-prompts-testa-voicepass"))]
async fn post_character_prompt_decide_discards_upon_rerecord(db: PgPool) {
    let response = post(db.clone(), "/recordings/prompts/testa/voicepass/decide?recording_url=http://example.com/newervoicepass", "SpeechResult=Rerecord.", true)        .await
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
    .bind("testa")
    .bind("voicepass")
    .fetch_one(&db)
    .await;

    assert_eq!(
        recording_url.unwrap().url,
        "http://example.com/old-voicepass"
    );

    assert_that(&response).redirects_to("/recordings/prompts/testa/voicepass");
}

#[sqlx::test(fixtures("schema", "recordings-prompts-testa-voicepass"))]
async fn post_character_prompt_decide_discards_and_forwards_unrecorded(db: PgPool) {
    let response = post(db, "/recordings/prompts/testa/voicepass/decide?unrecorded&recording_url=http://example.com/newervoicepass", "SpeechResult=Rerecord.", true).await
        .expect("Failed to execute request.");

    assert_that(&response).redirects_to("/recordings/prompts/testa/voicepass?unrecorded");
}
