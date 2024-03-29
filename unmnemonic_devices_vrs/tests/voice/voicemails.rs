use crate::common;
use common::helpers::{get, get_config, post_with_twilio};

use select::{document::Document, predicate::Name};
use serde::Serialize;
use serde_json::json;
use speculoos::prelude::*;
use sqlx::PgPool;
use unmnemonic_devices_vrs::InjectableServices;
use wiremock::matchers::{body_string, method, path_regex};
use wiremock::{Mock, MockServer, ResponseTemplate};

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
pub struct Recording {
    url: String,
    call_id: String,
}

#[sqlx::test(fixtures("schema", "calls"))]
async fn post_voicemail_stores_voicemail_and_notifies(db: PgPool) {
    let config = get_config();
    let vrs_number = config.vrs_number.to_string();
    let conductor_number = config.conductor_number.to_string();

    let twilio_create_message_body = serde_urlencoded::to_string([
        ("Body", &"There is a new voicemail for knut".to_string()),
        ("To", &conductor_number),
        ("From", &vrs_number),
    ])
    .expect("Could not encode message creation body");

    let mock_twilio = MockServer::start().await;

    Mock::given(method("POST"))
        .and(path_regex(r"^/2010-04-01/Accounts/.*/Messages.json$"))
        .and(body_string(twilio_create_message_body.to_string()))
        .respond_with(ResponseTemplate::new(201).set_body_json(json!({})))
        .expect(1)
        .named("create message")
        .mount(&mock_twilio)
        .await;

    let response = post_with_twilio(
        InjectableServices {
            db: db.clone(),
            twilio_address: mock_twilio.uri(),
        },
        "/voicemails/knut",
        "RecordingUrl=http://example.com/voicemail&CallSid=xyz",
        false,
    )
    .await
    .expect("Failed to execute request.");

    let recording = sqlx::query_as::<_, Recording>(
        r#"
        SELECT
          r.url, r.call_id
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

    assert_eq!(
        recording.as_ref().unwrap().url,
        "http://example.com/voicemail"
    );
    assert_eq!(recording.unwrap().call_id, "xyz");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text())
        .contains("Thank you for your message");
}

#[sqlx::test(fixtures("schema", "users"))]
async fn get_voicemails_remember_confirm_gathers_user_voicepass(db: PgPool) {
    let response = get(db, "/voicemails/remember/confirm", false)
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
            .attr("hints")
            .unwrap(),
    )
    .contains("helminthological, phraseologically, ");
}

#[sqlx::test(fixtures("schema", "users"))]
async fn post_voicemails_remember_confirm_updates_user_notifies_and_redirects(db: PgPool) {
    let config = get_config();
    let vrs_number = config.vrs_number.to_string();
    let conductor_number = config.conductor_number.to_string();

    let twilio_create_message_body = serde_urlencoded::to_string([
        ("Body", &"User one@example.com has remembered".to_string()),
        ("To", &conductor_number),
        ("From", &vrs_number),
    ])
    .expect("Could not encode message creation body");

    let mock_twilio = MockServer::start().await;

    Mock::given(method("POST"))
        .and(path_regex(r"^/2010-04-01/Accounts/.*/Messages.json$"))
        .and(body_string(twilio_create_message_body.to_string()))
        .respond_with(ResponseTemplate::new(201).set_body_json(json!({})))
        .expect(1)
        .named("create message")
        .mount(&mock_twilio)
        .await;

    let body = "SpeechResult=Helminthological.";

    let response = post_with_twilio(
        InjectableServices {
            db: db.clone(),
            twilio_address: mock_twilio.uri(),
        },
        "/voicemails/remember/confirm",
        body,
        true,
    )
    .await
    .expect("Failed to execute response");

    let text = response.text().await.unwrap();
    let document = Document::from(text.as_str());

    assert_that(&document.find(Name("say")).next().unwrap().text()).contains("being willing");

    let remembered = sqlx::query!(
        "SELECT remembered from users WHERE id = '7d907360-f19e-4518-ae58-23eef4e8281f'"
    )
    .fetch_one(&db)
    .await
    .expect("Failed to fetch user remembered");
    assert_eq!(remembered.remembered.unwrap(), 1);
}

#[sqlx::test(fixtures("schema", "users-with-no-voicepass"))]
async fn post_voicemails_remember_confirm_errors_when_unrecognised_notifies_and_redirects(
    db: PgPool,
) {
    let config = get_config();
    let vrs_number = config.vrs_number.to_string();
    let conductor_number = config.conductor_number.to_string();

    let twilio_create_message_body = serde_urlencoded::to_string([
        (
            "Body",
            &"Failed to confirm remember: this voicepass does not exist".to_string(),
        ),
        ("To", &conductor_number),
        ("From", &vrs_number),
    ])
    .expect("Could not encode message creation body");

    let mock_twilio = MockServer::start().await;

    Mock::given(method("POST"))
        .and(path_regex(r"^/2010-04-01/Accounts/.*/Messages.json$"))
        .and(body_string(twilio_create_message_body.to_string()))
        .respond_with(ResponseTemplate::new(201).set_body_json(json!({})))
        .expect(1)
        .named("create message")
        .mount(&mock_twilio)
        .await;

    let body = "SpeechResult=This voicepass does not exist.";

    let response = post_with_twilio(
        InjectableServices {
            db: db.clone(),
            twilio_address: mock_twilio.uri(),
        },
        "/voicemails/remember/confirm",
        body,
        true,
    )
    .await
    .expect("Failed to execute response");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());
    let redirect = document.find(Name("redirect")).next().unwrap();

    assert_that(&redirect.text()).contains("/voicemails/remember/confirm");
    assert_eq!(redirect.attr("method").unwrap(), "GET");
}
