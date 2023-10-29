mod helpers {
    include!("../helpers.rs");
}
use helpers::get;

use select::{
    document::Document,
    predicate::{Class, Descendant, Name},
};
use speculoos::prelude::*;
use sqlx::PgPool;

#[sqlx::test(fixtures(
    "schema",
    "teams",
    "regions",
    "books",
    "destinations",
    "meetings",
    "meetings-progress"
))]
async fn teams_list(db: PgPool) {
    let response = get(db, "/admin/teams", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(
        response.headers().get("Content-Type").unwrap(),
        "text/html; charset=utf-8"
    );

    let document = Document::from(response.text().await.unwrap().as_str());
    let row = document
        .find(Descendant(Name("tbody"), Class("team")))
        .next()
        .unwrap();

    assert_that(&row.text()).contains("jortles");
    assert_that(&row.text()).contains("a voicepass");
    assert_that(&row.text()).contains("Cornish Library: 0");
    assert_that(&row.text()).contains("LI: 2");
}
