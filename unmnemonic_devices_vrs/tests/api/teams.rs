use crate::helpers::spawn_app;
use select::{document::Document, predicate::Name};
use speculoos::prelude::*;
use sqlx::PgPool;

#[sqlx::test(fixtures("schema", "teams"))]
async fn teams_show_gathers_team_voicepasses(db: PgPool) {
    let app_address = spawn_app(db).await.address;

    let client = reqwest::Client::new();

    let response = client
        .get(&format!("{}/teams", &app_address))
        .send()
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
async fn teams_post_redirects_to_found_voicepass_team(db: PgPool) {
    let app_address = spawn_app(db).await.address;

    let client = reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::none())
        .build()
        .expect("Failed to construct request client");

    // Twilio editorialises punctuation and always capitalises.
    let body = "SpeechResult=This is another, voicepass?";

    let response = client
        .post(&format!("{}/teams", &app_address))
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(body)
        .send()
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_redirection());
    assert_eq!(
        response
            .headers()
            .get("Location")
            .expect("Failed to extract Location header")
            .to_str()
            .unwrap(),
        "/teams/5f721b36-38bd-4504-a5aa-428e9447ab12"
    );
}

#[sqlx::test(fixtures("schema", "teams"))]
async fn teams_post_renders_not_found_when_no_voicepass_matches(db: PgPool) {
    let app_address = spawn_app(db).await.address;

    let client = reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::none())
        .build()
        .expect("Failed to construct request client");

    let body = "SpeechResult=This voicepass does not exist.";

    let response = client
        .post(&format!("{}/teams", &app_address))
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(body)
        .send()
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());
    let redirect = document.find(Name("redirect")).next().unwrap();

    assert_that(&redirect.text()).contains("/teams");
    assert_eq!(redirect.attr("method").unwrap(), "GET");
}

#[sqlx::test(fixtures("schema", "teams"))]
async fn team_show_names_team(db: PgPool) {
    let app_address = spawn_app(db).await.address;

    let client = reqwest::Client::new();

    let response = client
        .get(&format!(
            "{}/teams/48e3bda7-db52-4c99-985f-337e266f7832",
            &app_address
        ))
        .send()
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());
    let say = document.find(Name("say")).next().unwrap();

    assert_that(&say.text()).contains("jortles");
}
