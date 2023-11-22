use crate::common;
use common::helpers::{get, post, RedirectTo};

use select::{document::Document, predicate::Name};
use serde::Serialize;
use speculoos::prelude::*;
use sqlx::PgPool;
use uuid::uuid;

#[sqlx::test(fixtures("schema", "regions", "destinations", "recordings-voicemails"))]
async fn get_destinations_gathers_by_synthetic_id(db: PgPool) {
    let response = get(db, "/recordings/destinations", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    let gather_hints = &document
        .find(Name("gather"))
        .next()
        .unwrap()
        .attr("hints")
        .unwrap();

    assert_that(gather_hints).contains("unrecorded");
    assert_that(gather_hints).contains("1");
    assert_that(gather_hints).contains("2");
}

#[sqlx::test(fixtures("schema", "regions", "destinations", "destinations-recordings-all"))]
async fn get_destinations_does_not_listen_for_unrecorded_when_there_are_none(db: PgPool) {
    let response = get(db, "/recordings/destinations", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    let gather_hints = &document
        .find(Name("gather"))
        .next()
        .unwrap()
        .attr("hints")
        .unwrap();

    assert_that(gather_hints).does_not_contain("unrecorded");
}

#[sqlx::test(fixtures("schema", "regions", "destinations"))]
async fn post_recordings_redirects(db: PgPool) {
    for (speech_result, redirect) in [
        (
            "2.",
            "/recordings/destinations/836a0b80-8a07-702a-b5ae-6506c712c1e0",
        ),
        (
            "1.",
            "/recordings/destinations/ac7a854d-274d-b26e-b85f-355fc6aa14ec",
        ),
        ("Unrecorded.", "/recordings/destinations/unrecorded"),
    ] {
        let response = post(
            db.clone(),
            "/recordings/destinations",
            &format!("SpeechResult={}", speech_result),
            true,
        )
        .await
        .expect("Failed to execute request.");

        assert_that(&response).redirects_to(redirect);
    }
}

#[sqlx::test(fixtures("schema", "regions", "destinations", "destinations-recordings",))]
async fn get_recording_destinations_unrecorded_redirects_to_first_unrecorded_destination_path(
    db: PgPool,
) {
    let response = get(db, "/recordings/destinations/unrecorded", true)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text())
        .contains("Cycling through unrecorded destinations");

    let redirect = document.find(Name("redirect")).next().unwrap();

    assert_that(&redirect.text())
        .contains("/recordings/destinations/ac7a854d-274d-b26e-b85f-355fc6aa14ec?unrecorded");
    assert_eq!(redirect.attr("method").unwrap(), "GET");
}

#[sqlx::test(fixtures("schema", "regions", "destinations", "destinations-recordings-all",))]
async fn get_recording_destinations_unrecorded_skips_message_with_unrecorded_param(db: PgPool) {
    let response = get(db, "/recordings/prompts/testa/unrecorded?unrecorded", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("response")).next().unwrap().text())
        .does_not_contain("through unrecorded");
}

#[sqlx::test(fixtures("schema", "regions", "destinations"))]
async fn post_recordings_destinations_handles_not_found(db: PgPool) {
    let response = post(
        db.clone(),
        "/recordings/destinations",
        "SpeechResult=9997766",
        true,
    )
    .await
    .expect("Failed to execute request.");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text())
        .contains("Unable to find destination 9997766");

    let redirect = document.find(Name("redirect")).next().unwrap();

    assert_that(&redirect.text()).contains("/recordings/destinations");
    assert_eq!(redirect.attr("method").unwrap(), "GET");
}

#[sqlx::test(fixtures("schema", "regions", "destinations"))]
async fn get_recording_destination(db: PgPool) {
    let response = get(
        db.clone(),
        "/recordings/destinations/836A0B80-8A07-702A-B5AE-6506C712C1E0",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text())
        .contains("Recording destination 2");

    let record_element = &document.find(Name("record")).next().unwrap();

    assert_eq!(
        record_element.attr("action").unwrap(),
        "/recordings/destinations/836a0b80-8a07-702a-b5ae-6506c712c1e0"
    );

    let unrecorded_response = get(
        db,
        "/recordings/destinations/836a0b80-8a07-702a-b5ae-6506c712c1e0?unrecorded",
        false,
    )
    .await
    .expect("Failed to execute request.");

    let unrecorded_document = Document::from(unrecorded_response.text().await.unwrap().as_str());
    let unrecorded_record_element = &unrecorded_document.find(Name("record")).next().unwrap();

    assert_eq!(
        unrecorded_record_element.attr("action").unwrap(),
        "/recordings/destinations/836a0b80-8a07-702a-b5ae-6506c712c1e0?unrecorded"
    );
}

#[sqlx::test(fixtures("schema"))]
async fn post_recording_destination_plays_recording_and_gathers_decision(db: PgPool) {
    let response = post(
        db.clone(),
        "/recordings/destinations/D62514A8-ED66-A272-9D83-BC696BC6852A",
        "RecordingUrl=http://example.com/a-cornish-recording&CallSid=hmm",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_eq!(
        &document.find(Name("play")).next().unwrap().text(),
        "http://example.com/a-cornish-recording"
    );

    assert_eq!(
      &document
          .find(Name("gather"))
          .next()
          .unwrap()
          .attr("action")
          .unwrap(),
      &"/recordings/destinations/d62514a8-ed66-a272-9d83-bc696bc6852a/decide?recording_url=http%3A%2F%2Fexample.com%2Fa-cornish-recording"
  );

    let unrecorded_response = post(
        db,
        "/recordings/destinations/D62514A8-ED66-A272-9D83-BC696BC6852A?unrecorded",
        "RecordingUrl=http://example.com/a-cornish-recording&CallSid=hmm",
        false,
    )
    .await
    .expect("Failed to execute request.");

    let unrecorded_document = Document::from(unrecorded_response.text().await.unwrap().as_str());

    assert_eq!(
      &unrecorded_document
          .find(Name("gather"))
          .next()
          .unwrap()
          .attr("action")
          .unwrap(),
      &"/recordings/destinations/d62514a8-ed66-a272-9d83-bc696bc6852a/decide?recording_url=http%3A%2F%2Fexample.com%2Fa-cornish-recording&unrecorded"
    );
}

#[derive(Debug, sqlx::FromRow, Serialize)]
pub struct Recording {
    url: String,
    call_id: Option<String>,
}

#[sqlx::test(fixtures("schema", "regions", "destinations", "calls"))]
async fn post_recording_destination_decide_stores_recording_upon_keep(db: PgPool) {
    let response = post(
        db.clone(),
        "/recordings/destinations/836A0B80-8A07-702A-B5AE-6506C712C1E0/decide?recording_url=http://example.com/new-cornish-recording",
        "SpeechResult=Keep.&CallSid=ANOTHER_SID",
        true,
    )
    .await
    .expect("Failed to execute request.");

    let recording_url = sqlx::query_as::<_, Recording>(
        r#"
          SELECT
            r.url, r.call_id
          FROM
            unmnemonic_devices.recordings r
          WHERE
            r.destination_id = $1
        "#,
    )
    .bind(uuid!("836A0B80-8A07-702A-B5AE-6506C712C1E0"))
    .fetch_one(&db)
    .await;

    assert_eq!(
        recording_url.as_ref().unwrap().url,
        "http://example.com/new-cornish-recording"
    );
    assert_eq!(recording_url.unwrap().call_id.unwrap(), "ANOTHER_SID");

    assert_that(&response).redirects_to("/recordings/destinations");

    let unrecorded_response = post(
      db.clone(),
      "/recordings/destinations/836A0B80-8A07-702A-B5AE-6506C712C1E0/decide?recording_url=http://example.com/new-cornish-recording&unrecorded",
      "SpeechResult=Keep.&CallSid=ANOTHER_SID",
      true,
  )
  .await
  .expect("Failed to execute request.");

    assert_that(&unrecorded_response)
        .redirects_to("/recordings/destinations/unrecorded?unrecorded");
}

#[sqlx::test(fixtures(
    "schema",
    "regions",
    "destinations",
    "destinations-recordings",
    "calls"
))]
async fn post_recording_destination_decide_discards_recording_upon_rerecord(db: PgPool) {
    let response = post(
        db.clone(),
        "/recordings/destinations/836A0B80-8A07-702A-B5AE-6506C712C1E0/decide?recording_url=http://example.com/new-cornish-recording",
        "SpeechResult=Rerecord.&CallSid=ANOTHER_SID",
        true,
    )
    .await
    .expect("Failed to execute request.");

    let recording_url = sqlx::query_as::<_, Recording>(
        r#"
          SELECT
            r.url, r.call_id
          FROM
            unmnemonic_devices.recordings r
          WHERE
            r.destination_id = $1
        "#,
    )
    .bind(uuid!("836A0B80-8A07-702A-B5AE-6506C712C1E0"))
    .fetch_one(&db)
    .await;

    assert_eq!(
        recording_url.as_ref().unwrap().url,
        "http://example.com/destination-recording"
    );
    assert!(recording_url.unwrap().call_id.is_none());

    assert_that(&response)
        .redirects_to("/recordings/destinations/836a0b80-8a07-702a-b5ae-6506c712c1e0");

    let unrecorded_response = post(
      db.clone(),
      "/recordings/destinations/836A0B80-8A07-702A-B5AE-6506C712C1E0/decide?recording_url=http://example.com/new-cornish-recording&unrecorded",
      "SpeechResult=Rerecord.&CallSid=ANOTHER_SID",
      true,
  )
  .await
  .expect("Failed to execute request.");

    assert_that(&unrecorded_response)
        .redirects_to("/recordings/destinations/836a0b80-8a07-702a-b5ae-6506c712c1e0?unrecorded");
}
