mod helpers {
    include!("../helpers.rs");
}
use helpers::get;

use select::{
    document::Document,
    predicate::{Class, Descendant, Name, Predicate},
};
use speculoos::prelude::*;
use sqlx::PgPool;

#[sqlx::test(fixtures(
    "schema",
    "teams",
    "teams-progress",
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
    let complete_row = document
        .find(Descendant(
            Name("tbody"),
            Class("team").and(Class("complete")),
        ))
        .next()
        .unwrap();

    assert_that(&complete_row.text()).contains("jortles");
    assert_that(&complete_row.text()).contains("a voicepass");
    assert_that(&complete_row.text()).contains("Cornish Library: 0");
    assert_that(&complete_row.text()).contains("LI: 2");

    let incomplete_row = document
        .find(Class("team").and(Class("incomplete")))
        .next()
        .unwrap();

    assert_that(&incomplete_row.text()).contains("tortles");
}
