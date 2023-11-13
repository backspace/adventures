mod helpers {
    include!("../helpers.rs");
}
use helpers::get;

use select::{
    document::Document,
    predicate::{Name, Predicate},
};
use speculoos::prelude::*;
use sqlx::PgPool;

#[sqlx::test(fixtures("schema", "regions", "destinations"))]
async fn list_destinations(db: PgPool) {
    let response = get(db, "/admin/destinations", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(
        response.headers().get("Content-Type").unwrap(),
        "text/html; charset=utf-8"
    );

    let document = Document::from(response.text().await.unwrap().as_str());

    let row_count = document.find(Name("tbody").descendant(Name("tr"))).count();
    assert_eq!(row_count, 2);

    let audio_count = document.find(Name("audio")).count();
    assert_eq!(audio_count, 0);

    let first_row = document
        .find(Name("tbody").descendant(Name("tr")))
        .next()
        .unwrap();

    assert_that(&first_row.text()).contains("this is the destination description");
    assert_that(&first_row.text()).contains("1");
}

#[sqlx::test(fixtures("schema", "regions", "destinations", "destinations-recordings"))]
async fn list_destinations_with_audio(db: PgPool) {
    let response = get(db, "/admin/destinations", false)
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
    assert_eq!(audio_src, "http://example.com/destination-recording");
}
