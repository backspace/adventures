use crate::helpers::spawn_app;
use chrono::Utc;
use sqlx::PgPool;

#[sqlx::test(fixtures("schema"))]
async fn teams_show_gathers_team_voicepasses(db: PgPool) {
    sqlx::query!(
        r#"
      INSERT INTO teams (id, name, voicepass, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $5), ($6, $7, $8, $9, $10)
      "#,
        1,
        "jortles",
        "here is a voicepass",
        Utc::now().naive_utc(),
        Utc::now().naive_utc(),
        2,
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
    assert!(response
        .text()
        .await
        .unwrap()
        .contains("hints=\"here is a voicepass, this is another voicepass, \""));
}

#[sqlx::test(fixtures("schema"))]
async fn teams_post_redirects_to_found_voicepass_team(db: PgPool) {
    sqlx::query!(
        r#"
        INSERT INTO teams (id, name, voicepass, inserted_at, updated_at)
        VALUES ($1, $2, $3, $4, $5), ($6, $7, $8, $9, $10)
        "#,
        1,
        "jortles",
        "here is a voicepass",
        Utc::now().naive_utc(),
        Utc::now().naive_utc(),
        2,
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

    let body = "SpeechResult=This is another voicepass.";

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
        "/teams/2"
    );
}

#[sqlx::test(fixtures("schema"))]
async fn teams_post_renders_not_found_when_no_voicepass_matches(db: PgPool) {
    sqlx::query!(
        r#"
        INSERT INTO teams (id, name, voicepass, inserted_at, updated_at)
        VALUES ($1, $2, $3, $4, $5)
        "#,
        1,
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
    assert!(response
        .text()
        .await
        .unwrap()
        .contains("<Redirect method=\"GET\">/teams</Redirect>"));
}

#[sqlx::test(fixtures("schema"))]
async fn team_show_names_team(db: PgPool) {
    sqlx::query!(
        r#"
      INSERT INTO teams (id, name, voicepass, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $5)
      "#,
        1,
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
        .get(&format!("{}/teams/1", &app_address))
        .send()
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");
    assert!(response.text().await.unwrap().contains("jortle"));
}
