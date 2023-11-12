mod helpers {
    include!("../helpers.rs");
}
use helpers::{get, get_with_twilio, post, RedirectTo};

use select::{
    document::Document,
    predicate::{Descendant, Name},
};
use serde::Serialize;
use serde_json::json;
use speculoos::prelude::*;
use sqlx::PgPool;
use std::env;
use unmnemonic_devices_vrs::config::{ConfigProvider, EnvVarProvider};
use unmnemonic_devices_vrs::InjectableServices;
use wiremock::matchers::{body_string, method, path_regex};
use wiremock::{Mock, MockServer, ResponseTemplate};

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
    assert_that(&response.text().await.unwrap()).contains("chromatin");

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

#[sqlx::test(fixtures("schema", "settings-override"))]
async fn root_plays_override_when_it_exists(db: PgPool) {
    let response = get(db.clone(), "/?CallSid=xyz&Caller=2040000000", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");
    assert_that(&response.text().await.unwrap()).contains("this is an override");
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
    .contains("Chromatin");

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

#[sqlx::test(fixtures("schema", "settings", "recordings-prompts-pure-chromatin"))]
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
    .contains("http://example.com/chromatin");
}

#[sqlx::test(fixtures("schema", "settings-begun"))]
async fn root_serves_welcome_and_notifies_supervisor_when_begun(db: PgPool) {
    let env_config_provider = EnvVarProvider::new(env::vars().collect());
    let config = &env_config_provider.get_config();
    let twilio_number = config.twilio_number.to_string();
    let supervisor_number = config.supervisor_number.to_string();

    let twilio_create_message_body = serde_urlencoded::to_string([
        ("Body", &"New call from 2040000000".to_string()),
        ("To", &supervisor_number),
        ("From", &twilio_number),
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

    let response = get_with_twilio(
        InjectableServices {
            db: db.clone(),
            twilio_address: mock_twilio.uri(),
        },
        "/?Caller=2040000000",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");
    assert_that(&response.text().await.unwrap()).contains("welcome to unmnemonic");
}

#[sqlx::test(fixtures("schema", "settings-begun"))]
async fn root_serves_welcome_and_does_not_notify_self_call_when_begun(db: PgPool) {
    let env_config_provider = EnvVarProvider::new(env::vars().collect());
    let config = &env_config_provider.get_config();
    let supervisor_number = config.supervisor_number.to_string();

    let response = get(
        db,
        &format!("/?Caller={}", urlencoding::encode(&supervisor_number)),
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
}

#[sqlx::test(fixtures("schema", "settings"))]
async fn root_serves_welcome_when_query_param_begin(db: PgPool) {
    let response = get(db, "/?begun", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");
    assert_that(&response.text().await.unwrap()).contains("welcome to unmnemonic");
}

#[sqlx::test(fixtures("schema", "settings-ending"))]
async fn root_serves_ending_when_ending(db: PgPool) {
    let response = get(db, "/", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");
    assert_that(&response.text().await.unwrap()).contains("Placeholder for ending message");
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
