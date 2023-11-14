mod helpers {
    include!("../helpers.rs");
}
use helpers::get;

use select::{
    document::Document,
    predicate::{Attr, Class, Descendant, Name, Predicate},
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

#[sqlx::test(fixtures("schema", "teams"))]
async fn list_team_recordings(db: PgPool) {
    let response = get(db, "/admin/teams", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(
        response.headers().get("Content-Type").unwrap(),
        "text/html; charset=utf-8"
    );

    let document = Document::from(response.text().await.unwrap().as_str());

    let row_count = document
        .find(
            Attr("data-test-recordings", ())
                .descendant(Name("tbody"))
                .descendant(Name("tr")),
        )
        .count();
    assert_eq!(row_count, 2);

    let audio_count = document.find(Name("audio")).count();
    assert_eq!(audio_count, 0);

    let first_row = document
        .find(
            Attr("data-test-recordings", ())
                .descendant(Name("tbody"))
                .descendant(Name("tr")),
        )
        .next()
        .unwrap();

    assert_that(&first_row.text()).contains("a voicepass");
    assert_that(&first_row.text()).contains("1");
}

#[sqlx::test(fixtures("schema", "teams", "teams-recordings"))]
async fn list_teams_with_audio(db: PgPool) {
    let response = get(db, "/admin/teams", false)
        .await
        .expect("Failed to execute request.");

    let document = Document::from(response.text().await.unwrap().as_str());

    let audio_count = document.find(Name("audio")).count();
    assert_eq!(audio_count, 1);

    let audio_src = document
        .find(Name("audio"))
        .next()
        .unwrap()
        .attr("src")
        .unwrap();
    assert_eq!(audio_src, "http://example.com/team-recording");
}
