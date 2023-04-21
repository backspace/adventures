use crate::helpers::get;
use select::{document::Document, predicate::Name};
use speculoos::prelude::*;
use sqlx::PgPool;

#[sqlx::test(fixtures("schema", "teams", "books", "regions", "destinations", "meetings"))]
async fn meeting_show_names_region(db: PgPool) {
    let response = get(db, "/meetings/DE805DAF-28E7-F7A9-8CB2-9806730B54E5", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());
    let say = document.find(Name("say")).next().unwrap();

    assert_that(&say.text()).contains("Cornish Library");
}
