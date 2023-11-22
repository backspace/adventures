use crate::common;
use common::helpers::{get, post, RedirectTo};

use select::{document::Document, predicate::Name};
use serde::Serialize;
use speculoos::prelude::*;
use sqlx::PgPool;
use uuid::uuid;

#[sqlx::test(fixtures("schema", "regions", "recordings-voicemails"))]
async fn get_regions_gathers_by_synthetic_id(db: PgPool) {
    let response = get(db, "/recordings/regions", false)
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

#[sqlx::test(fixtures("schema", "regions", "regions-recordings-all"))]
async fn get_regions_does_not_listen_for_unrecorded_when_there_are_none(db: PgPool) {
    let response = get(db, "/recordings/regions", false)
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

#[sqlx::test(fixtures("schema", "regions"))]
async fn post_recordings_redirects(db: PgPool) {
    for (speech_result, redirect) in [
        (
            "2.",
            "/recordings/regions/d62514a8-ed66-a272-9d83-bc696bc6852a",
        ),
        (
            "1.",
            "/recordings/regions/ad7707cf-899a-482f-8f8b-13b2a3b77ed5",
        ),
        ("Unrecorded.", "/recordings/regions/unrecorded"),
    ] {
        let response = post(
            db.clone(),
            "/recordings/regions",
            &format!("SpeechResult={}", speech_result),
            true,
        )
        .await
        .expect("Failed to execute request.");

        assert_that(&response).redirects_to(redirect);
    }
}

#[sqlx::test(fixtures("schema", "regions", "regions-recordings",))]
async fn get_recording_regions_unrecorded_redirects_to_first_unrecorded_region_path(db: PgPool) {
    let response = get(db, "/recordings/regions/unrecorded", true)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text())
        .contains("Cycling through unrecorded regions");

    let redirect = document.find(Name("redirect")).next().unwrap();

    assert_that(&redirect.text())
        .contains("/recordings/regions/ad7707cf-899a-482f-8f8b-13b2a3b77ed5?unrecorded");
    assert_eq!(redirect.attr("method").unwrap(), "GET");
}

#[sqlx::test(fixtures("schema", "regions", "regions-recordings-all",))]
async fn get_recording_regions_unrecorded_skips_message_with_unrecorded_param(db: PgPool) {
    let response = get(db, "/recordings/prompts/testa/unrecorded?unrecorded", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("response")).next().unwrap().text())
        .does_not_contain("through unrecorded");
}

#[sqlx::test(fixtures("schema", "regions"))]
async fn post_recordings_regions_handles_not_found(db: PgPool) {
    let response = post(
        db.clone(),
        "/recordings/regions",
        "SpeechResult=9997766",
        true,
    )
    .await
    .expect("Failed to execute request.");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text())
        .contains("Unable to find region 9997766");

    let redirect = document.find(Name("redirect")).next().unwrap();

    assert_that(&redirect.text()).contains("/recordings/regions");
    assert_eq!(redirect.attr("method").unwrap(), "GET");
}

#[sqlx::test(fixtures("schema", "regions"))]
async fn get_recording_region(db: PgPool) {
    let response = get(
        db.clone(),
        "/recordings/regions/D62514A8-ED66-A272-9D83-BC696BC6852A",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text()).contains("Recording region 2");

    let record_element = &document.find(Name("record")).next().unwrap();

    assert_eq!(
        record_element.attr("action").unwrap(),
        "/recordings/regions/d62514a8-ed66-a272-9d83-bc696bc6852a"
    );

    let unrecorded_response = get(
        db,
        "/recordings/regions/D62514A8-ED66-A272-9D83-BC696BC6852A?unrecorded",
        false,
    )
    .await
    .expect("Failed to execute request.");

    let unrecorded_document = Document::from(unrecorded_response.text().await.unwrap().as_str());
    let unrecorded_record_element = &unrecorded_document.find(Name("record")).next().unwrap();

    assert_eq!(
        unrecorded_record_element.attr("action").unwrap(),
        "/recordings/regions/d62514a8-ed66-a272-9d83-bc696bc6852a?unrecorded"
    );
}

#[sqlx::test(fixtures("schema"))]
async fn post_recording_region_plays_recording_and_gathers_decision(db: PgPool) {
    let response = post(
        db.clone(),
        "/recordings/regions/D62514A8-ED66-A272-9D83-BC696BC6852A",
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
      &"/recordings/regions/d62514a8-ed66-a272-9d83-bc696bc6852a/decide?recording_url=http%3A%2F%2Fexample.com%2Fa-cornish-recording"
  );

    let unrecorded_response = post(
        db,
        "/recordings/regions/D62514A8-ED66-A272-9D83-BC696BC6852A?unrecorded",
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
      &"/recordings/regions/d62514a8-ed66-a272-9d83-bc696bc6852a/decide?recording_url=http%3A%2F%2Fexample.com%2Fa-cornish-recording&unrecorded"
    );
}

#[derive(Debug, sqlx::FromRow, Serialize)]
pub struct Recording {
    url: String,
    call_id: Option<String>,
}

#[sqlx::test(fixtures("schema", "regions", "calls"))]
async fn post_recording_region_decide_stores_recording_upon_keep(db: PgPool) {
    let response = post(
        db.clone(),
        "/recordings/regions/D62514A8-ED66-A272-9D83-BC696BC6852A/decide?recording_url=http://example.com/new-cornish-recording",
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
            r.region_id = $1
        "#,
    )
    .bind(uuid!("D62514A8-ED66-A272-9D83-BC696BC6852A"))
    .fetch_one(&db)
    .await;

    assert_eq!(
        recording_url.as_ref().unwrap().url,
        "http://example.com/new-cornish-recording"
    );
    assert_eq!(recording_url.unwrap().call_id.unwrap(), "ANOTHER_SID");

    assert_that(&response).redirects_to("/recordings/regions");

    let unrecorded_response = post(
      db.clone(),
      "/recordings/regions/D62514A8-ED66-A272-9D83-BC696BC6852A/decide?recording_url=http://example.com/new-cornish-recording&unrecorded",
      "SpeechResult=Keep.&CallSid=ANOTHER_SID",
      true,
  )
  .await
  .expect("Failed to execute request.");

    assert_that(&unrecorded_response).redirects_to("/recordings/regions/unrecorded?unrecorded");
}

#[sqlx::test(fixtures("schema", "regions", "regions-recordings", "calls"))]
async fn post_recording_region_decide_discards_recording_upon_rerecord(db: PgPool) {
    let response = post(
        db.clone(),
        "/recordings/regions/D62514A8-ED66-A272-9D83-BC696BC6852A/decide?recording_url=http://example.com/new-cornish-recording",
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
            r.region_id = $1
        "#,
    )
    .bind(uuid!("D62514A8-ED66-A272-9D83-BC696BC6852A"))
    .fetch_one(&db)
    .await;

    assert_eq!(
        recording_url.as_ref().unwrap().url,
        "http://example.com/cornish-recording"
    );
    assert!(recording_url.unwrap().call_id.is_none());

    assert_that(&response).redirects_to("/recordings/regions/d62514a8-ed66-a272-9d83-bc696bc6852a");

    let unrecorded_response = post(
      db.clone(),
      "/recordings/regions/D62514A8-ED66-A272-9D83-BC696BC6852A/decide?recording_url=http://example.com/new-cornish-recording&unrecorded",
      "SpeechResult=Rerecord.&CallSid=ANOTHER_SID",
      true,
  )
  .await
  .expect("Failed to execute request.");

    assert_that(&unrecorded_response)
        .redirects_to("/recordings/regions/d62514a8-ed66-a272-9d83-bc696bc6852a?unrecorded");
}
