use crate::helpers::spawn_app;
use chrono::Utc;
use sqlx::PgPool;

#[sqlx::test(fixtures("schema"))]
async fn root_serves_prewelcome(db: PgPool) {
    sqlx::query!(
        r#"
        INSERT INTO unmnemonic_devices.settings (id, inserted_at, updated_at)
        VALUES ($1, $2, $3)
        "#,
        1,
        Utc::now().naive_utc(),
        Utc::now().naive_utc(),
    )
    .execute(&db)
    .await
    .expect("Failed to insert settings row");

    let app_address = spawn_app(db).await.address;

    let client = reqwest::Client::new();

    let response = client
        .get(&format!("{}/", &app_address))
        .send()
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");
    assert!(response.text().await.unwrap().contains("unmnemonic"));
}

#[sqlx::test(fixtures("schema"))]
async fn root_serves_welcome_when_begun(db: PgPool) {
    sqlx::query!(
        r#"
        INSERT INTO unmnemonic_devices.settings (id, begun, inserted_at, updated_at)
        VALUES ($1, $2, $3, $4)
        "#,
        1,
        true,
        Utc::now().naive_utc(),
        Utc::now().naive_utc(),
    )
    .execute(&db)
    .await
    .expect("Failed to insert settings row");

    let app_address = spawn_app(db).await.address;

    let client = reqwest::Client::new();

    let response = client
        .get(&format!("{}/", &app_address))
        .send()
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");
    assert!(response.text().await.unwrap().contains("Has it begun"));
}

#[sqlx::test(fixtures("schema"))]
async fn root_serves_welcome_when_query_param_begin(db: PgPool) {
    sqlx::query!(
        r#"
        INSERT INTO unmnemonic_devices.settings (id, inserted_at, updated_at)
        VALUES ($1, $2, $3)
        "#,
        1,
        Utc::now().naive_utc(),
        Utc::now().naive_utc(),
    )
    .execute(&db)
    .await
    .expect("Failed to insert settings row");

    let app_address = spawn_app(db).await.address;

    let client = reqwest::Client::new();

    let response = client
        .get(&format!("{}/?begun", &app_address))
        .send()
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");
    assert!(response.text().await.unwrap().contains("Has it begun"));
}

#[sqlx::test(fixtures("schema"))]
async fn root_post_begun_redirects_to_root_begun(db: PgPool) {
    let app_address = spawn_app(db).await.address;

    let client = reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::none())
        .build()
        .expect("Failed to construct request client");

    let body = "SpeechResult=Begun.";

    let response = client
        .post(&format!("{}/", &app_address))
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
        "/?begun"
    );
}

#[sqlx::test(fixtures("schema"))]
async fn root_post_else_redirects_to_root(db: PgPool) {
    let app_address = spawn_app(db).await.address;

    let client = reqwest::Client::builder()
        .redirect(reqwest::redirect::Policy::none())
        .build()
        .expect("Failed to construct request client");

    let body = "SpeechResult=whatever";

    let response = client
        .post(&format!("{}/", &app_address))
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
        "/"
    );
}
