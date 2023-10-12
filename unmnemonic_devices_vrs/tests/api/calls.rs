use crate::helpers::get_with_twilio;
use select::{
    document::Document,
    predicate::{Descendant, Name},
};
use serde_json::json;
use speculoos::prelude::*;
use sqlx::PgPool;
use unmnemonic_devices_vrs::InjectableServices;
use wiremock::matchers::any;
use wiremock::{Mock, MockServer, ResponseTemplate};

// FIXME this isn’t an API!

#[sqlx::test()]
async fn calls_list_when_empty(db: PgPool) {
    let mock_twilio = MockServer::start().await;

    Mock::given(any())
        .respond_with(ResponseTemplate::new(200).set_body_json(json!({"calls": []})))
        .expect(1)
        .mount(&mock_twilio)
        .await;

    let response = get_with_twilio(
        InjectableServices {
            db,
            twilio_address: Some(mock_twilio.uri()),
        },
        "/calls",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(
        response.headers().get("Content-Type").unwrap(),
        "text/html; charset=utf-8"
    );

    let document = Document::from(response.text().await.unwrap().as_str());
    let row = document
        .find(Descendant(Name("tbody"), Name("tr")))
        .next()
        .unwrap();

    assert_that(&row.text()).contains("no calls");
}

#[sqlx::test()]
async fn calls_list_with_calls(db: PgPool) {
    let mock_twilio = MockServer::start().await;

    Mock::given(any())
        .respond_with(
            ResponseTemplate::new(200).set_body_json(json!({"calls": [{"from": "+15145551212"}]})),
        )
        .expect(1)
        .mount(&mock_twilio)
        .await;

    let response = get_with_twilio(
        InjectableServices {
            db,
            twilio_address: Some(mock_twilio.uri()),
        },
        "/calls",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(
        response.headers().get("Content-Type").unwrap(),
        "text/html; charset=utf-8"
    );

    let document = Document::from(response.text().await.unwrap().as_str());
    let row = document
        .find(Descendant(Name("tbody"), Name("tr")))
        .next()
        .unwrap();

    assert_that(&row.text()).contains("+15145551212");
}
