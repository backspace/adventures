use crate::common;
use common::helpers::{get_config, get_with_twilio, get_with_twilio_and_auth, post_with_twilio};

use select::{
    document::Document,
    predicate::{Class, Descendant, Name},
};
use serde_json::json;
use speculoos::prelude::*;
use sqlx::PgPool;
use unmnemonic_devices_vrs::InjectableServices;
use wiremock::matchers::{body_string, method, path_regex, query_param};
use wiremock::{Mock, MockServer, ResponseTemplate};

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
        "/admin/calls",
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

#[sqlx::test(fixtures("schema", "teams", "calls-teams"))]
async fn calls_list_with_calls_and_teams_and_paths(db: PgPool) {
    let mock_twilio = MockServer::start().await;

    Mock::given(method("GET"))
        .and(path_regex(r"^/2010-04-01/Accounts/.*/Calls.json$"))
        .and(query_param("Status", "in-progress"))
        .respond_with(
            ResponseTemplate::new(200).set_body_json(json!({"calls": [{"sid": "AN_SID", "from": "+15145551212", "start_time": "Tue, 03 Oct 2023 05:39:58 +0000"}]})),
        )
        .expect(1)
        .mount(&mock_twilio)
        .await;

    let response = get_with_twilio(
        InjectableServices {
            db,
            twilio_address: mock_twilio.uri(),
        },
        "/admin/calls",
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
        .find(Descendant(Name("tbody"), Class("call")))
        .next()
        .unwrap();

    assert_eq!(
        &row.attr("data-sid")
            .expect("Expected data-test-sid attribute on .call"),
        &"AN_SID"
    );
    assert_that(&row.text()).contains("Tue, 03 Oct 2023 05:39:58 +0000");
    assert_that(&row.text()).contains("+15145551212");
    assert_that(&row.text()).contains("tortles");
    assert_that(&row.text()).contains("/a-path");
}

#[sqlx::test(fixtures("schema", "teams", "calls-teams", "users-maybe-admin"))]
async fn calls_list_with_admin_user_from_database(db: PgPool) {
    let mock_twilio = MockServer::start().await;

    Mock::given(method("GET"))
        .and(path_regex(r"^/2010-04-01/Accounts/.*/Calls.json$"))
        .and(query_param("Status", "in-progress"))
        .respond_with(
            ResponseTemplate::new(200).set_body_json(json!({"calls": [{"sid": "AN_SID", "from": "+15145551212", "start_time": "Tue, 03 Oct 2023 05:39:58 +0000"}]})),
        )
        .expect(1)
        .mount(&mock_twilio)
        .await;

    let response = get_with_twilio_and_auth(
        InjectableServices {
            db,
            twilio_address: mock_twilio.uri(),
        },
        "/admin/calls",
        false,
        "admin@example.com:this-is-my-password".to_string(),
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(
        response.headers().get("Content-Type").unwrap(),
        "text/html; charset=utf-8"
    );
}

#[sqlx::test(fixtures("schema", "teams", "calls-teams", "users-maybe-admin"))]
async fn calls_list_with_non_admin_user_from_database(db: PgPool) {
    let mock_twilio = MockServer::start().await;

    let response = get_with_twilio_and_auth(
        InjectableServices {
            db,
            twilio_address: mock_twilio.uri(),
        },
        "/admin/calls",
        false,
        "nonadmin@example.com:this-is-my-password".to_string(),
    )
    .await
    .expect("Failed to execute request.");

    assert_eq!(response.status(), 401);
}

#[sqlx::test(fixtures("schema"))]
async fn create_call_success(db: PgPool) {
    let config = get_config();
    let vrs_number = config.vrs_number.to_string();

    let twilio_call_create_body = serde_urlencoded::to_string([
        ("Method", &"GET".to_string()),
        ("Url", &format!("{}conferences/SID", config.root_url)),
        ("To", &"NUMBER".to_string()),
        ("From", &vrs_number),
    ])
    .expect("Could not encode call creation body");

    let twilio_call_update_body = serde_urlencoded::to_string([
        ("Method", "GET"),
        ("Url", &format!("{}conferences/SID", config.root_url)),
    ])
    .expect("Could not encode call update body");

    let mock_twilio = MockServer::start().await;

    Mock::given(method("POST"))
        .and(path_regex(r"^/2010-04-01/Accounts/.*/Calls.json$"))
        .and(body_string(twilio_call_create_body.to_string()))
        .respond_with(ResponseTemplate::new(201).set_body_json(json!({})))
        .expect(1)
        .named("create call")
        .mount(&mock_twilio)
        .await;

    Mock::given(method("POST"))
        .and(path_regex(r"^/2010-04-01/Accounts/.*/Calls/SID.json$"))
        .and(body_string(twilio_call_update_body.to_string()))
        .respond_with(ResponseTemplate::new(201).set_body_json(json!({})))
        .expect(1)
        .named("update call")
        .mount(&mock_twilio)
        .await;

    let response = post_with_twilio(
        InjectableServices {
            db,
            twilio_address: mock_twilio.uri(),
        },
        "/admin/calls",
        "to=NUMBER&sid=SID",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
}

#[sqlx::test(fixtures("schema"))]
async fn create_call_creation_failure(db: PgPool) {
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
        "/admin/calls",
        "to=NUMBER&sid=SID",
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

#[sqlx::test(fixtures("schema"))]
async fn create_call_update_failure(db: PgPool) {
    let config = get_config();
    let vrs_number = config.vrs_number.to_string();

    let mock_twilio = MockServer::start().await;
    let twilio_json_response = json!({"code": 21201, "message": "No 'To' number is specified", "more_info": "https://www.twilio.com/docs/errors/21201", "status": 400});

    let twilio_call_create_body = serde_urlencoded::to_string([
        ("Method", "GET"),
        ("Url", &format!("{}conferences/SID", config.root_url)),
        ("To", "NUMBER"),
        ("From", &vrs_number),
    ])
    .expect("Could not encode call creation body");

    Mock::given(method("POST"))
        .and(path_regex(r"^/2010-04-01/Accounts/.*/Calls.json$"))
        .and(body_string(twilio_call_create_body.to_string()))
        .respond_with(ResponseTemplate::new(201).set_body_json(json!({})))
        .expect(1)
        .named("create call")
        .mount(&mock_twilio)
        .await;

    Mock::given(method("POST"))
        .and(path_regex(r"^/2010-04-01/Accounts/.*/Calls/SID.json$"))
        .respond_with(ResponseTemplate::new(400).set_body_json(twilio_json_response))
        .expect(1)
        .named("failure to update call")
        .mount(&mock_twilio)
        .await;

    let response = post_with_twilio(
        InjectableServices {
            db,
            twilio_address: mock_twilio.uri(),
        },
        "/admin/calls",
        "to=NUMBER&sid=SID",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_client_error());

    let response_text = response.text().await.expect("Unable to read response text");

    let response_json: serde_json::Value =
        serde_json::from_str(&response_text).unwrap_or_else(|_| {
            panic!(
                "Unable to read JSON from response text: `{}`",
                response_text
            )
        });

    assert_eq!(
        response_json,
        json!({"code": 21201, "message": "No 'To' number is specified", "more_info": "https://www.twilio.com/docs/errors/21201", "status": 400})
    );
}
