use crate::helpers::spawn_app;
use chrono::Utc;
use speculoos::prelude::*;
use sqlx::{types::Uuid, PgPool};

#[sqlx::test(fixtures("schema"))]
async fn teams_show_gathers_team_voicepasses(db: PgPool) {
    sqlx::query!(
        r#"
      INSERT INTO teams (id, name, voicepass, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $5), ($6, $7, $8, $9, $10)
      "#,
        Uuid::parse_str("48e3bda7-db52-4c99-985f-337e266f7832").expect("Failed to parse uuid"),
        "jortles",
        "here is a voicepass",
        Utc::now().naive_utc(),
        Utc::now().naive_utc(),
        Uuid::parse_str("5f721b36-38bd-4504-a5aa-428e9447ab12").expect("Failed to parse uuid"),
        "tortles",
        "this is another voicepass",
        Utc::now().naive_utc(),
        Utc::now().naive_utc(),
    )
    .execute(&db)
    .await
    .expect("Failed to insert team rows");

    let app_address = spawn_app(db).await.address;

    let client = reqwest::Client::new();

    let response = client
        .get(&format!("{}/teams", &app_address))
        .send()
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");
    assert_that(&response.text().await.unwrap())
        .contains("hints=\"here is a voicepass, this is another voicepass, \"");
}

#[sqlx::test(fixtures("schema"))]
async fn teams_post_redirects_to_found_voicepass_team(db: PgPool) {
    sqlx::query!(
        r#"
        INSERT INTO teams (id, name, voicepass, inserted_at, updated_at)
        VALUES ($1, $2, $3, $4, $5), ($6, $7, $8, $9, $10)
        "#,
        Uuid::parse_str("48e3bda7-db52-4c99-985f-337e266f7832").expect("Failed to parse uuid"),
        "jortles",
        "here is a voicepass",
        Utc::now().naive_utc(),
        Utc::now().naive_utc(),
        Uuid::parse_str("5f721b36-38bd-4504-a5aa-428e9447ab12").expect("Failed to parse uuid"),
        "tortles",
        "this is another voicepass",
        Utc::now().naive_utc(),
        Utc::now().naive_utc(),
    )
    .execute(&db)
    .await
    .expect("Failed to insert team rows");

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

#[sqlx::test(fixtures("schema"))]
async fn teams_post_renders_not_found_when_no_voicepass_matches(db: PgPool) {
    sqlx::query!(
        r#"
        INSERT INTO teams (id, name, voicepass, inserted_at, updated_at)
        VALUES ($1, $2, $3, $4, $5)
        "#,
        Uuid::parse_str("48e3bda7-db52-4c99-985f-337e266f7832").expect("Failed to parse uuid"),
        "jortles",
        "here is a voicepass",
        Utc::now().naive_utc(),
        Utc::now().naive_utc(),
    )
    .execute(&db)
    .await
    .expect("Failed to insert team rows");

    let app_address = spawn_app(db).await.address;

    let client = reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::none())
        .build()
        .expect("Failed to construct request client");

    let body = "SpeechResult=This is another voicepass.";

    let response = client
        .post(&format!("{}/teams", &app_address))
        .header("Content-Type", "application/x-www-form-urlencoded")
        .body(body)
        .send()
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");
    assert_that(&response.text().await.unwrap())
        .contains("<Redirect method=\"GET\">/teams</Redirect>");
}

#[sqlx::test(fixtures("schema"))]
async fn team_show_names_team(db: PgPool) {
    sqlx::query!(
        r#"
      INSERT INTO teams (id, name, voicepass, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $5)
      "#,
        Uuid::parse_str("48e3bda7-db52-4c99-985f-337e266f7832").expect("Failed to parse uuid"),
        "jortles",
        "a voicepass",
        Utc::now().naive_utc(),
        Utc::now().naive_utc(),
    )
    .execute(&db)
    .await
    .expect("Failed to insert team row");

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
    assert_that(&response.text().await.unwrap()).contains("jortle");
}
