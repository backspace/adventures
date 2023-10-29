use crate::helpers::{get, get_with_twilio, post, RedirectTo};
use select::{document::Document, predicate::Name};
use serde_json::json;
use speculoos::prelude::*;
use sqlx::PgPool;
use std::env;
use unmnemonic_devices_vrs::config::{ConfigProvider, EnvVarProvider};
use unmnemonic_devices_vrs::InjectableServices;
use wiremock::matchers::{body_string, method, path_regex};
use wiremock::{Mock, MockServer, ResponseTemplate};

#[sqlx::test(fixtures("schema", "teams", "teams-with-no-voicepass"))]
async fn teams_show_gathers_team_voicepasses(db: PgPool) {
    let response = get(db, "/teams", false)
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
    .contains("a voicepass, this is another voicepass, ");
}

#[sqlx::test(fixtures("schema", "teams"))]
async fn teams_post_redirects_to_found_voicepass_team_confirmation(db: PgPool) {
    // Twilio editorialises punctuation and always capitalises.
    let body = "SpeechResult=This is not another, voicepass?";

    let response = post(db, "/teams", body, true)
        .await
        .expect("Failed to execute response");
    assert_that(&response).redirects_to("/teams/5f721b36-38bd-4504-a5aa-428e9447ab12/confirm");
}

#[sqlx::test(fixtures("schema", "teams"))]
async fn teams_post_renders_not_found_when_no_voicepass_matches(db: PgPool) {
    let body = "SpeechResult=This voicepass does not exist.";

    let response = post(db, "/teams", body, true)
        .await
        .expect("Failed to execute response");
    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());
    let redirect = document.find(Name("redirect")).next().unwrap();

    assert_that(&redirect.text()).contains("/teams");
    assert_eq!(redirect.attr("method").unwrap(), "GET");
}

#[sqlx::test(fixtures("schema", "teams"))]
async fn team_get_confirm_gathers_voicepass_confirmation(db: PgPool) {
    let response = get(
        db,
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832/confirm",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());
    let say = document.find(Name("say")).next().unwrap();

    assert_that(&say.text()).contains("a voicepass");
}

#[sqlx::test(fixtures("schema"))]
async fn team_get_confirm_redirects_to_show_teams_for_nonexistent_team(db: PgPool) {
    let response = get(
        db,
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832/confirm",
        true,
    )
    .await
    .expect("Failed to execute request.");

    assert_that(&response).redirects_to("/teams");
}

#[sqlx::test(fixtures("schema", "teams"))]
async fn team_post_confirm_redirects_to_team_show_on_yes(db: PgPool) {
    let response = post(
        db.clone(),
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832/confirm",
        "SpeechResult=Yes. Yes.",
        true,
    )
    .await
    .expect("Failed to execute request.");

    assert_that(&response).redirects_to("/teams/48e3bda7-db52-4c99-985f-337e266f7832");

    let yeah_response = post(
        db,
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832/confirm",
        "SpeechResult=Yeah.",
        true,
    )
    .await
    .expect("Failed to execute request.");

    assert_that(&yeah_response).redirects_to("/teams/48e3bda7-db52-4c99-985f-337e266f7832");
}

#[sqlx::test(fixtures("schema", "teams"))]
async fn team_post_confirm_redirects_to_teams_show_on_no(db: PgPool) {
    let response = post(
        db,
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832/confirm",
        "SpeechResult=No.",
        true,
    )
    .await
    .expect("Failed to execute request.");

    assert_that(&response).redirects_to("/teams");
}

#[sqlx::test(fixtures("schema", "teams", "books", "regions", "destinations", "meetings"))]
async fn team_show_names_team_and_gathers_excerpts_or_collation(db: PgPool) {
    let response = get(db, "/teams/48e3bda7-db52-4c99-985f-337e266f7832", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());
    let say = document.find(Name("say")).next().unwrap();

    assert_that(&say.text()).contains("jortles");

    let hints = &document
        .find(Name("gather"))
        .next()
        .unwrap()
        .attr("hints")
        .unwrap();

    assert_that(hints).contains("abused or ignored,");
    assert_that(hints).contains("schnimbleby,");
    assert_that(hints).contains("another answer an answer");
}

#[sqlx::test(fixtures("schema", "teams", "books", "regions", "destinations", "meetings"))]
async fn team_post_redirects_to_found_excerpt_meeting(db: PgPool) {
    // Twilio editorialises punctuation and always capitalises.
    let body = "SpeechResult=Abused and ignored.";

    let response = post(
        db,
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832",
        body,
        true,
    )
    .await
    .expect("Failed to execute request.");

    assert_that(&response).redirects_to("/meetings/2460cb8f-bd7f-4790-a2d8-86df38d5cbdc");
}

#[sqlx::test(fixtures("schema", "teams", "books", "regions", "destinations", "meetings"))]
async fn team_post_renders_not_found_when_no_excerpt_matches(db: PgPool) {
    let response = post(
        db,
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832",
        "SpeechResult=What does it all mean.",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());
    let redirect = document.find(Name("redirect")).next().unwrap();

    assert_that(&redirect.text()).contains("/teams/48e3bda7-db52-4c99-985f-337e266f7832");
    assert_eq!(redirect.attr("method").unwrap(), "GET");
}

#[sqlx::test(fixtures("schema", "teams", "books", "regions", "destinations", "meetings"))]
async fn team_post_redirects_to_completion(db: PgPool) {
    // Twilio editorialises punctuation and always capitalises.
    let body = "SpeechResult=Another answer an answer.";

    let response = post(
        db.clone(),
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832",
        body,
        true,
    )
    .await
    .expect("Failed to execute request.");

    assert_that(&response).redirects_to("/teams/48e3bda7-db52-4c99-985f-337e266f7832/complete");

    let fuzzy_body = "SpeechResult=another answer an ax answer an an answer.";

    let fuzzy_response = post(
        db,
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832",
        fuzzy_body,
        true,
    )
    .await
    .expect("Failed to execute request.");

    assert_that(&fuzzy_response)
        .redirects_to("/teams/48e3bda7-db52-4c99-985f-337e266f7832/complete");
}

#[sqlx::test(fixtures("schema", "teams"))]
async fn team_get_complete_notifies_and_increments_listens(db: PgPool) {
    let env_config_provider = EnvVarProvider::new(env::vars().collect());
    let config = &env_config_provider.get_config();
    let twilio_number = config.twilio_number.to_string();
    let notification_number = config.notification_number.to_string();

    let twilio_create_message_body = serde_urlencoded::to_string([
        ("Body", &"FIXME ya party time".to_string()),
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
            db,
            twilio_address: mock_twilio.uri(),
        },
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832/complete",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");
}
