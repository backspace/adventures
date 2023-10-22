use crate::helpers::{get_with_twilio, post_with_twilio};

use select::{
    document::Document,
    predicate::{Descendant, Name},
};
use serde_json::json;
use speculoos::prelude::*;
use sqlx::PgPool;
use std::env;
use unmnemonic_devices_vrs::config::{ConfigProvider, EnvVarProvider};
use unmnemonic_devices_vrs::InjectableServices;
use wiremock::matchers::{body_string, method, path_regex, query_param};
use wiremock::{Mock, MockServer, ResponseTemplate};

// FIXME this isn’t an API!

#[sqlx::test(fixtures("schema"))]
async fn calls_list_when_empty(db: PgPool) {
    let mock_twilio = MockServer::start().await;

    Mock::given(method("GET"))
        .and(path_regex(r"^/2010-04-01/Accounts/.*/Calls.json$"))
        .and(query_param("Status", "in-progress"))
        .respond_with(ResponseTemplate::new(200).set_body_json(json!({"calls": []})))
        .expect(1)
        .mount(&mock_twilio)
        .await;

    let response = get_with_twilio(
        InjectableServices {
            db,
            twilio_address: mock_twilio.uri(),
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

#[sqlx::test(fixtures("schema"))]
async fn calls_list_with_calls(db: PgPool) {
    let mock_twilio = MockServer::start().await;

    Mock::given(method("GET"))
        .and(path_regex(r"^/2010-04-01/Accounts/.*/Calls.json$"))
        .and(query_param("Status", "in-progress"))
        .respond_with(
            ResponseTemplate::new(200).set_body_json(json!({"calls": [{"from": "+15145551212", "start_time": "Tue, 03 Oct 2023 05:39:58 +0000"}]})),
        )
        .expect(1)
        .mount(&mock_twilio)
        .await;

    let response = get_with_twilio(
        InjectableServices {
            db,
            twilio_address: mock_twilio.uri(),
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

    assert_that(&row.text()).contains("Tue, 03 Oct 2023 05:39:58 +0000");
    assert_that(&row.text()).contains("+15145551212");
}

#[sqlx::test(fixtures("schema"))]
async fn create_call_success(db: PgPool) {
    let env_config_provider = EnvVarProvider::new(env::vars().collect());
    let config = &env_config_provider.get_config();
    let twilio_number = config.twilio_number.to_string();

    let twilio_post_body = serde_urlencoded::to_string([
        ("Url", &config.root_url.to_string()),
        ("Method", &"GET".to_string()),
        ("To", &"NUMBER".to_string()),
        ("From", &twilio_number),
    ])
    .expect("Could not encode");

    let mock_twilio = MockServer::start().await;

    Mock::given(method("POST"))
        .and(path_regex(r"^/2010-04-01/Accounts/.*/Calls.json$"))
        .and(body_string(twilio_post_body.to_string()))
        .respond_with(ResponseTemplate::new(201).set_body_json(json!({})))
        .expect(1)
        .mount(&mock_twilio)
        .await;

    let response = post_with_twilio(
        InjectableServices {
            db,
            twilio_address: mock_twilio.uri(),
        },
        "/calls",
        "to=NUMBER",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
}

#[sqlx::test(fixtures("schema"))]
async fn create_call_failure(db: PgPool) {
    let mock_twilio = MockServer::start().await;
    let twilio_json_response = json!({"code": 21201, "message": "No 'To' number is specified", "more_info": "https://www.twilio.com/docs/errors/21201", "status": 400});

    Mock::given(method("POST"))
        .and(path_regex(r"^/2010-04-01/Accounts/.*/Calls.json$"))
        .respond_with(ResponseTemplate::new(400).set_body_json(twilio_json_response))
        .expect(1)
        .mount(&mock_twilio)
        .await;

    let response = post_with_twilio(
        InjectableServices {
            db,
            twilio_address: mock_twilio.uri(),
        },
        "/calls",
        "to=NUMBER",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_client_error());

    let response_json: serde_json::Value = response
        .json()
        .await
        .expect("Failed to parse JSON response");
    assert_eq!(
        response_json,
        json!({"code": 21201, "message": "No 'To' number is specified", "more_info": "https://www.twilio.com/docs/errors/21201", "status": 400})
    );
}
