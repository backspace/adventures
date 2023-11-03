mod helpers {
    include!("../helpers.rs");
}
use helpers::get;

use select::{
    document::Document,
    predicate::{Attr, Name, Predicate},
};
use speculoos::prelude::*;
use sqlx::PgPool;

#[sqlx::test(fixtures("schema"))]
async fn list_prompts(db: PgPool) {
    let response = get(db, "/admin/prompts", false)
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(
        response.headers().get("Content-Type").unwrap(),
        "text/html; charset=utf-8"
    );

    let document = Document::from(response.text().await.unwrap().as_str());

    let table_count = document.find(Name("table")).count();
    assert_eq!(table_count, 5);

    let audio_count = document.find(Name("audio")).count();
    assert_eq!(audio_count, 0);

    let testa_prompt_count = document
        .find(Attr("data-character", "testa").descendant(Name("tr")))
        .count();
    assert_eq!(testa_prompt_count, 2);

    let knut_prompt_row = document
        .find(
            Attr("data-character", "knut")
                .descendant(Name("tbody"))
                .descendant(Name("tr")),
        )
        .next()
        .unwrap();
    assert_that(&knut_prompt_row.text()).contains("voicemail");
    assert_that(&knut_prompt_row.text()).contains("please leave");
    assert_that(&knut_prompt_row.text()).contains("⚠️");
}

#[sqlx::test(fixtures("schema", "recordings-prompts-pure-monitoring"))]
async fn list_prompts_with_audio(db: PgPool) {
    let response = get(db, "/admin/prompts", false)
        .await
        .expect("Failed to execute request.");

    let document = Document::from(response.text().await.unwrap().as_str());

    let audio_count = document.find(Name("audio")).count();
    assert_eq!(audio_count, 1);
}
