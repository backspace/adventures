mod helpers {
    include!("../helpers.rs");
}
use helpers::{get, post, RedirectTo};

use select::{document::Document, predicate::Name};
use serde::Serialize;
use speculoos::prelude::*;
use sqlx::PgPool;

#[sqlx::test(fixtures("schema"))]
async fn get_voicemail_pure_sets_up_recording(db: PgPool) {
    let response = get(db, "/voicemails/knut", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());
    assert_that(&document.find(Name("say")).next().unwrap().text()).contains("knut");

    let record_element = &document.find(Name("record")).next().unwrap();
    assert_eq!(record_element.attr("action").unwrap(), "/voicemails/knut");
}

#[derive(sqlx::FromRow, Serialize)]
pub struct RecordingUrl {
    url: String,
}

#[sqlx::test(fixtures("schema"))]
async fn post_voicemail_stores_voicemail(db: PgPool) {
    let response = post(
        db.clone(),
        "/voicemails/knut",
        "RecordingUrl=http://example.com/voicemail",
        false,
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
          AND r.type = $2
      "#,
    )
    .bind("knut")
    .bind("voicemail")
    .fetch_one(&db)
    .await;

    assert_eq!(recording_url.unwrap().url, "http://example.com/voicemail");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text())
        .contains("Thank you for your message");
}
