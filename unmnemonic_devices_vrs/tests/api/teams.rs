use crate::helpers::spawn_app;
use chrono::Utc;
use sqlx::PgPool;

#[sqlx::test(fixtures("schema"))]
async fn team_show_names_team(db: PgPool) {
    sqlx::query!(
        r#"
      INSERT INTO teams (id, name, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4)
      "#,
        1,
        "jortles",
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
    assert_eq!(
        response.headers().get("Content-Type").unwrap(),
        "application/xml"
    );
    assert!(response.text().await.unwrap().contains("jortle"));
}
