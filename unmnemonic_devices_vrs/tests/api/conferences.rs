use crate::helpers::get;

use select::{document::Document, predicate::Name};
use sqlx::PgPool;

#[sqlx::test(fixtures("schema"))]
async fn conferences_show_uses_sid_for_conference(db: PgPool) {
    let response = get(db, "/conferences/SID", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());
    let conference = document.find(Name("conference")).next().unwrap();

    assert_eq!(&conference.text(), "Room SID");
}
