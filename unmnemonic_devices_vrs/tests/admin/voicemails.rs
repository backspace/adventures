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

#[sqlx::test(fixtures("schema", "recordings-prompts-pure-welcome", "recordings-voicemails"))]
async fn teams_list(db: PgPool) {
    let response = get(db, "/admin/voicemails", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(
        response.headers().get("Content-Type").unwrap(),
        "text/html; charset=utf-8"
    );

    let document = Document::from(response.text().await.unwrap().as_str());
    let row_count = document.find(Descendant(Name("tbody"), Name("tr"))).count();

    assert_eq!(row_count, 6);

    let first_unapproved_row = document
        .find(Name("tr").and(Class("unapproved")))
        .next()
        .unwrap();
    assert_that(&first_unapproved_row.text()).contains("knut");
    assert_eq!(
        &first_unapproved_row
            .find(Name("audio"))
            .next()
            .unwrap()
            .attr("src")
            .unwrap(),
        &"http://example.com/voicemail-old"
    );

    let first_row = document
        .find(Descendant(Name("tbody"), Name("tr")))
        .next()
        .unwrap();
    assert_eq!(
        &first_row
            .find(Name("audio"))
            .next()
            .unwrap()
            .attr("src")
            .unwrap(),
        &"http://example.com/voicemail-old"
    );

    let rejected_row = document
        .find(Name("tr").and(Class("unapproved")))
        .last()
        .unwrap();
    assert_that(&rejected_row.text()).contains("rejected");
}
