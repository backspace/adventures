use crate::helpers::{get, post, RedirectTo};
use select::{document::Document, predicate::Name};
use speculoos::prelude::*;
use sqlx::PgPool;

#[sqlx::test(fixtures("schema", "teams"))]
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
    let body = "SpeechResult=This is another, voicepass?";

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
        db,
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832/confirm",
        "SpeechResult=Yes.",
        true,
    )
    .await
    .expect("Failed to execute request.");

    assert_that(&response).redirects_to("/teams/48e3bda7-db52-4c99-985f-337e266f7832");
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
    let body = "SpeechResult=Abused or ignored.";

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
        db,
        "/teams/48e3bda7-db52-4c99-985f-337e266f7832",
        body,
        true,
    )
    .await
    .expect("Failed to execute request.");

    assert_that(&response).redirects_to("/teams/48e3bda7-db52-4c99-985f-337e266f7832/complete");
}
