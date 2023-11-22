use crate::common;
use common::helpers::{get, post};

use select::{
    document::Document,
    predicate::{Class, Descendant, Name, Predicate},
};
use speculoos::prelude::*;
use sqlx::PgPool;
use uuid::uuid;

#[sqlx::test(fixtures(
    "schema",
    "recordings-prompts-pure-welcome",
    "recordings-voicemails",
    "teams",
    "calls",
    "calls-teams",
    "recordings-to-team-call"
))]
async fn list_voicemails(db: PgPool) {
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
    assert_eq!(
        &first_unapproved_row.attr("data-id").unwrap(),
        &"4a578222-9a0e-48f0-a023-2be7d873849f"
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

    assert_that(&first_row.text()).contains("tortles");

    let rejected_row = document
        .find(Name("tr").and(Class("unapproved")))
        .last()
        .unwrap();
    assert_that(&rejected_row.text()).contains("rejected");
}

#[sqlx::test(fixtures("schema", "recordings-voicemails"))]
async fn update_voicemails(db: PgPool) {
    let voicemail_id = uuid!("af9a306a-6913-4d83-90c4-f595ae020503");

    for (approved_string, approved_value) in [
        ("approved=true", Some(true)),
        ("approved=false", Some(false)),
        ("", None),
    ] {
        let response = post(
            db.clone(),
            &format!("/admin/voicemails/{}", voicemail_id),
            approved_string,
            true,
        )
        .await
        .expect("Failed to execute request.");

        assert!(response.status().is_success());

        let voicemail_approved_query = sqlx::query!(
            "SELECT approved FROM unmnemonic_devices.recordings WHERE id = $1",
            voicemail_id
        )
        .fetch_one(&db)
        .await
        .expect("Failed to fetch voicemail approved");

        assert_eq!(voicemail_approved_query.approved, approved_value);
    }
}
