use crate::common;
use common::helpers::{get, get_with_twilio, post, RedirectTo};

use select::{document::Document, predicate::Name};
use serde::Serialize;
use serde_json::json;
use speculoos::prelude::*;
use sqlx::{types::Uuid, PgPool};
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

#[sqlx::test(fixtures("schema", "teams", "teams-recordings-all"))]
async fn team_get_confirm_gathers_voicepass_confirmation_with_recorded_voicepass(db: PgPool) {
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
    let play = document.find(Name("play")).next().unwrap();

    assert_that(&play.text()).contains("http://example.com/other-team-recording");
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

#[sqlx::test(fixtures("schema", "teams", "teams-progress"))]
async fn team_post_confirm_redirects_to_team_complete_on_yes_when_team_is_complete(db: PgPool) {
    let response = post(
        db.clone(),
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832/confirm",
        "SpeechResult=Yes. Yes.",
        true,
    )
    .await
    .expect("Failed to execute request.");

    assert_that(&response).redirects_to("/teams/48e3bda7-db52-4c99-985f-337e266f7832/complete");
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

#[derive(sqlx::FromRow, Serialize)]
pub struct CallRecord {
    team_id: Uuid,
    path: String,
}

#[sqlx::test(fixtures(
    "schema",
    "teams",
    "books",
    "regions",
    "destinations",
    "meetings",
    "calls"
))]
async fn team_show_names_team_and_gathers_excerpts_or_collation_and_records_team_in_call(
    db: PgPool,
) {
    let response = get(
        db.clone(),
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832?CallSid=xyz",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    let hints = &document
        .find(Name("gather"))
        .next()
        .unwrap()
        .attr("hints")
        .unwrap();

    assert_that(hints).contains("abused or ignored,");
    assert_that(hints).contains("schnimbleby,");
    assert_that(hints).contains("another answer an answer");

    let call = sqlx::query_as::<_, CallRecord>(
        r#"
          SELECT
            team_id, path
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

    assert_eq!(
        call.team_id,
        uuid::uuid!("48e3bda7-db52-4c99-985f-337e266f7832")
    );
    assert_eq!(call.path, "/teams/48e3bda7-db52-4c99-985f-337e266f7832")
}

#[sqlx::test(fixtures(
    "schema",
    "teams",
    "books",
    "regions",
    "destinations",
    "meetings",
    "calls",
    "recordings-encouraging"
))]
async fn team_show_consumes_encouraging_message(db: PgPool) {
    let response = get(
        db.clone(),
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832?CallSid=xyz",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());

    let say = document.find(Name("say")).next().unwrap();
    assert_that(&say.text()).contains("encouraging");

    let play = document.find(Name("play")).next().unwrap();
    assert_that(&play.text()).contains("http://example.com/encouraging");

    let listens = sqlx::query!("SELECT team_listen_ids from unmnemonic_devices.recordings WHERE id = '975f5bc8-b527-4445-ad42-cddbd01fc216'").fetch_one(&db).await.expect("Failed to fetch recording listens");

    assert_eq!(
        listens.team_listen_ids.unwrap(),
        vec![uuid::uuid!("48e3bda7-db52-4c99-985f-337e266f7832")]
    );
}

#[sqlx::test(fixtures(
    "schema",
    "teams",
    "books",
    "regions",
    "destinations",
    "meetings",
    "calls",
    "recordings-encouraging",
    "recordings-encouraging-listened"
))]
async fn team_show_does_not_consume_consumed_message(db: PgPool) {
    let response = get(
        db.clone(),
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832?CallSid=xyz",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());
    let say = document.find(Name("say")).next().unwrap();

    assert_that(&say.text()).does_not_contain("encouraging");
}

#[sqlx::test(fixtures(
    "schema",
    "teams",
    "books",
    "regions",
    "destinations",
    "meetings",
    "calls",
    "recordings-encouraging-unapproved"
))]
async fn team_show_does_not_consume_unapproved_message(db: PgPool) {
    let response = get(
        db.clone(),
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832?CallSid=xyz",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());
    let say = document.find(Name("say")).next().unwrap();

    assert_that(&say.text()).does_not_contain("encouraging");
}

#[sqlx::test(fixtures(
    "schema",
    "teams",
    "books",
    "regions",
    "destinations",
    "meetings",
    "calls",
    "recordings-encouraging",
    "recordings-encouraging-listened"
))]
async fn team_show_does_not_consume_own_recording(db: PgPool) {
    let response = get(
        db.clone(),
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832?CallSid=xyz",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());
    let say = document.find(Name("say")).next().unwrap();

    assert_that(&say.text()).does_not_contain("encouraging");
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
    let vrs_number = config.vrs_number.to_string();
    let conductor_number = config.conductor_number.to_string();

    let twilio_create_message_body = serde_urlencoded::to_string([
        ("Body", &"Team jortles has completed".to_string()),
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

    let response = get_with_twilio(
        InjectableServices {
            db: db.clone(),
            twilio_address: mock_twilio.uri(),
        },
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832/complete",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let listens =
        sqlx::query!("SELECT listens from teams WHERE id = '48e3bda7-db52-4c99-985f-337e266f7832'")
            .fetch_one(&db)
            .await
            .expect("Failed to fetch meeting listens");

    assert_eq!(listens.listens.unwrap(), 1);
}

#[sqlx::test(fixtures("schema", "teams", "teams-progress"))]
async fn team_get_complete_does_not_repeat_notify(db: PgPool) {
    let response = get(
        db.clone(),
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832/complete",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let listens =
        sqlx::query!("SELECT listens from teams WHERE id = '48e3bda7-db52-4c99-985f-337e266f7832'")
            .fetch_one(&db)
            .await
            .expect("Failed to fetch meeting listens");

    assert_eq!(listens.listens.unwrap(), 3);
}

#[sqlx::test(fixtures("schema", "teams"))]
async fn team_post_complete_redirects(db: PgPool) {
    for (speech_result, redirect) in [
        (
            "Repeat.",
            "/teams/48e3bda7-db52-4c99-985f-337e266f7832/complete",
        ),
        ("Record.", "/voicemails/remember"),
        ("Recording an encouraging.", "/voicemails/remember"),
        ("End.", "/hangup"),
    ] {
        let response = post(
            db.clone(),
            "/teams/48e3bda7-db52-4c99-985f-337e266f7832/complete",
            // Twilio editorialises punctuation and always capitalises.
            &format!("SpeechResult={}", speech_result),
            true,
        )
        .await
        .expect("Failed to execute request.");

        assert_that(&response).redirects_to(redirect);
    }
}
