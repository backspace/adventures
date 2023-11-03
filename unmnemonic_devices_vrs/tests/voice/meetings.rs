mod helpers {
    include!("../helpers.rs");
}
use helpers::{get, get_with_twilio, post, RedirectTo};
use select::{document::Document, predicate::Name};
use serde_json::json;
use speculoos::prelude::*;
use sqlx::PgPool;
use std::env;
use unmnemonic_devices_vrs::config::{ConfigProvider, EnvVarProvider};
use unmnemonic_devices_vrs::InjectableServices;
use wiremock::matchers::{body_string, method, path_regex};
use wiremock::{Mock, MockServer, ResponseTemplate};

#[sqlx::test(fixtures("schema", "teams", "books", "regions", "destinations", "meetings"))]
async fn meeting_show_names_region_increments_listens_and_notifies(db: PgPool) {
    let env_config_provider = EnvVarProvider::new(env::vars().collect());
    let config = &env_config_provider.get_config();
    let twilio_number = config.twilio_number.to_string();
    let notification_number = config.notification_number.to_string();

    let twilio_create_message_body = serde_urlencoded::to_string([
        (
            "Body",
            &"Team: jortles\nBook: A Book Title\nDest: Cornish Library".to_string(),
        ),
        ("To", &notification_number),
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
        "/meetings/DE805DAF-28E7-F7A9-8CB2-9806730B54E5",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());
    let say = document.find(Name("say")).next().unwrap();

    assert_that(&say.text()).contains("Cornish Library");

    let listens = sqlx::query!("SELECT listens from unmnemonic_devices.meetings WHERE id = 'DE805DAF-28E7-F7A9-8CB2-9806730B54E5'").fetch_one(&db).await.expect("Failed to fetch meeting listens");

    assert_eq!(listens.listens.unwrap(), 1);
}

#[sqlx::test(fixtures(
    "schema",
    "teams",
    "books",
    "regions",
    "destinations",
    "meetings",
    "meetings-progress"
))]
async fn meeting_show_skips_notifications_on_subsequent_listens(db: PgPool) {
    let response = get(
        db.clone(),
        "/meetings/2460cb8f-bd7f-4790-a2d8-86df38d5cbdc",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
}

#[sqlx::test(fixtures("schema", "teams", "books", "regions", "destinations", "meetings"))]
async fn meeting_post_redirects_to_meeting_get_on_repeat(db: PgPool) {
    let response = post(
        db,
        "/meetings/DE805DAF-28E7-F7A9-8CB2-9806730B54E5",
        "SpeechResult=Repeat.",
        true,
    )
    .await
    .expect("Failed to execute request.");

    assert_that(&response).redirects_to("/meetings/de805daf-28e7-f7a9-8cb2-9806730b54e5");
}

#[sqlx::test(fixtures("schema", "teams", "books", "regions", "destinations", "meetings"))]
async fn meeting_post_redirects_to_voicemails_get_on_record(db: PgPool) {
    let response = post(
        db,
        "/meetings/DE805DAF-28E7-F7A9-8CB2-9806730B54E5",
        "SpeechResult=Record an encouraging.",
        true,
    )
    .await
    .expect("Failed to execute request.");

    assert_that(&response).redirects_to("/voicemails/remember");
}

#[sqlx::test(fixtures("schema", "teams", "books", "regions", "destinations", "meetings"))]
async fn meeting_post_redirects_to_hangup_on_end(db: PgPool) {
    let response = post(
        db,
        "/meetings/DE805DAF-28E7-F7A9-8CB2-9806730B54E5",
        "SpeechResult=End.",
        true,
    )
    .await
    .expect("Failed to execute request.");

    assert_that(&response).redirects_to("/hangup");
}
