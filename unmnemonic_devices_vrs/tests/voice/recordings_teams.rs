use crate::common;
use common::helpers::{get, post, RedirectTo};

use select::{document::Document, predicate::Name};
use serde::Serialize;
use speculoos::prelude::*;
use sqlx::PgPool;
use uuid::uuid;

#[sqlx::test(fixtures("schema", "teams", "recordings-voicemails"))]
async fn get_teams_gathers_by_synthetic_id(db: PgPool) {
    let response = get(db, "/recordings/teams", false)
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

#[sqlx::test(fixtures("schema", "teams", "teams-recordings-all"))]
async fn get_teams_does_not_listen_for_unrecorded_when_there_are_none(db: PgPool) {
    let response = get(db, "/recordings/teams", false)
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

#[sqlx::test(fixtures("schema", "teams"))]
async fn post_recordings_redirects(db: PgPool) {
    for (speech_result, redirect) in [
        (
            "2.",
            "/recordings/teams/5f721b36-38bd-4504-a5aa-428e9447ab12",
        ),
        (
            "1.",
            "/recordings/teams/48e3bda7-db52-4c99-985f-337e266f7832",
        ),
        ("Unrecorded.", "/recordings/teams/unrecorded"),
    ] {
        let response = post(
            db.clone(),
            "/recordings/teams",
            &format!("SpeechResult={}", speech_result),
            true,
        )
        .await
        .expect("Failed to execute request.");

        assert_that(&response).redirects_to(redirect);
    }
}

#[sqlx::test(fixtures("schema", "teams", "teams-recordings",))]
async fn get_recording_teams_unrecorded_redirects_to_first_unrecorded_team_path(db: PgPool) {
    let response = get(db, "/recordings/teams/unrecorded", true)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text())
        .contains("Cycling through unrecorded teams");

    let redirect = document.find(Name("redirect")).next().unwrap();

    assert_that(&redirect.text())
        .contains("/recordings/teams/48e3bda7-db52-4c99-985f-337e266f7832?unrecorded");
    assert_eq!(redirect.attr("method").unwrap(), "GET");
}

#[sqlx::test(fixtures("schema", "teams", "teams-recordings-all",))]
async fn get_recording_teams_unrecorded_skips_message_with_unrecorded_param(db: PgPool) {
    let response = get(db, "/recordings/teams/unrecorded?unrecorded", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("response")).next().unwrap().text())
        .does_not_contain("through unrecorded");
}

#[sqlx::test(fixtures("schema", "teams"))]
async fn post_recordings_teams_handles_not_found(db: PgPool) {
    let response = post(
        db.clone(),
        "/recordings/teams",
        "SpeechResult=9997766",
        true,
    )
    .await
    .expect("Failed to execute request.");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text())
        .contains("Unable to find team 9997766");

    let redirect = document.find(Name("redirect")).next().unwrap();

    assert_that(&redirect.text()).contains("/recordings/teams");
    assert_eq!(redirect.attr("method").unwrap(), "GET");
}

#[sqlx::test(fixtures("schema", "teams"))]
async fn get_recording_team(db: PgPool) {
    let response = get(
        db.clone(),
        "/recordings/teams/5f721b36-38bd-4504-a5aa-428e9447ab12",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text()).contains("Recording team 2");

    let record_element = &document.find(Name("record")).next().unwrap();

    assert_eq!(
        record_element.attr("action").unwrap(),
        "/recordings/teams/5f721b36-38bd-4504-a5aa-428e9447ab12"
    );

    let unrecorded_response = get(
        db,
        "/recordings/teams/5f721b36-38bd-4504-a5aa-428e9447ab12?unrecorded",
        false,
    )
    .await
    .expect("Failed to execute request.");

    let unrecorded_document = Document::from(unrecorded_response.text().await.unwrap().as_str());
    let unrecorded_record_element = &unrecorded_document.find(Name("record")).next().unwrap();

    assert_eq!(
        unrecorded_record_element.attr("action").unwrap(),
        "/recordings/teams/5f721b36-38bd-4504-a5aa-428e9447ab12?unrecorded"
    );
}

#[sqlx::test(fixtures("schema"))]
async fn post_recording_team_plays_recording_and_gathers_decision(db: PgPool) {
    let response = post(
        db.clone(),
        "/recordings/teams/48e3bda7-db52-4c99-985f-337e266f7832",
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
      &"/recordings/teams/48e3bda7-db52-4c99-985f-337e266f7832/decide?recording_url=http%3A%2F%2Fexample.com%2Fa-cornish-recording"
  );

    let unrecorded_response = post(
        db,
        "/recordings/teams/48e3bda7-db52-4c99-985f-337e266f7832?unrecorded",
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
      &"/recordings/teams/48e3bda7-db52-4c99-985f-337e266f7832/decide?recording_url=http%3A%2F%2Fexample.com%2Fa-cornish-recording&unrecorded"
    );
}

#[derive(Debug, sqlx::FromRow, Serialize)]
pub struct Recording {
    url: String,
    call_id: Option<String>,
}

#[sqlx::test(fixtures("schema", "teams", "calls"))]
async fn post_recording_team_decide_stores_recording_upon_save(db: PgPool) {
    let response = post(
        db.clone(),
        "/recordings/teams/5f721b36-38bd-4504-a5aa-428e9447ab12/decide?recording_url=http://example.com/new-cornish-recording",
        "SpeechResult=Save.&CallSid=ANOTHER_SID",
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
            r.team_id = $1
        "#,
    )
    .bind(uuid!("5f721b36-38bd-4504-a5aa-428e9447ab12"))
    .fetch_one(&db)
    .await;

    assert_eq!(
        recording_url.as_ref().unwrap().url,
        "http://example.com/new-cornish-recording"
    );
    assert_eq!(recording_url.unwrap().call_id.unwrap(), "ANOTHER_SID");

    assert_that(&response).redirects_to("/recordings/teams");

    let unrecorded_response = post(
      db.clone(),
      "/recordings/teams/5f721b36-38bd-4504-a5aa-428e9447ab12/decide?recording_url=http://example.com/new-cornish-recording&unrecorded",
      "SpeechResult=Save.&CallSid=ANOTHER_SID",
      true,
  )
  .await
  .expect("Failed to execute request.");

    assert_that(&unrecorded_response).redirects_to("/recordings/teams/unrecorded?unrecorded");
}

#[sqlx::test(fixtures("schema", "teams", "teams-recordings", "calls"))]
async fn post_recording_team_decide_discards_recording_upon_rerecord(db: PgPool) {
    let response = post(
        db.clone(),
        "/recordings/teams/5f721b36-38bd-4504-a5aa-428e9447ab12/decide?recording_url=http://example.com/new-cornish-recording",
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
            r.team_id = $1
        "#,
    )
    .bind(uuid!("5f721b36-38bd-4504-a5aa-428e9447ab12"))
    .fetch_one(&db)
    .await;

    assert_eq!(
        recording_url.as_ref().unwrap().url,
        "http://example.com/team-recording"
    );
    assert!(recording_url.unwrap().call_id.is_none());

    assert_that(&response).redirects_to("/recordings/teams/5f721b36-38bd-4504-a5aa-428e9447ab12");

    let unrecorded_response = post(
      db.clone(),
      "/recordings/teams/5f721b36-38bd-4504-a5aa-428e9447ab12/decide?recording_url=http://example.com/new-cornish-recording&unrecorded",
      "SpeechResult=Rerecord.&CallSid=ANOTHER_SID",
      true,
  )
  .await
  .expect("Failed to execute request.");

    assert_that(&unrecorded_response)
        .redirects_to("/recordings/teams/5f721b36-38bd-4504-a5aa-428e9447ab12?unrecorded");
}
