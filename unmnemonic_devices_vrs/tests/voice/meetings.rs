mod helpers {
    include!("../helpers.rs");
}
use helpers::{get, post, RedirectTo};

use select::{document::Document, predicate::Name};
use speculoos::prelude::*;
use sqlx::PgPool;

#[sqlx::test(fixtures("schema", "teams", "books", "regions", "destinations", "meetings"))]
async fn meeting_show_names_region_and_increments_listens(db: PgPool) {
    let response = get(
        db.clone(),
        "/meetings/DE805DAF-28E7-F7A9-8CB2-9806730B54E5",
        false,
    )
    .await
    .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert_eq!(response.headers().get("Content-Type").unwrap(), "text/xml");

    let document = Document::from(response.text().await.unwrap().as_str());
    let say = document.find(Name("say")).next().unwrap();

    assert_that(&say.text()).contains("Cornish Library");

    let listens = sqlx::query!("SELECT listens from unmnemonic_devices.meetings WHERE id = 'DE805DAF-28E7-F7A9-8CB2-9806730B54E5'").fetch_one(&db).await.expect("Failed to fetch meeting listens");

    assert_eq!(listens.listens.unwrap(), 1);
}

#[sqlx::test(fixtures("schema", "teams", "books", "regions", "destinations", "meetings"))]
async fn meeting_post_redirects_to_meeting_get_on_repeat(db: PgPool) {
    let response = post(
        db,
        "/meetings/DE805DAF-28E7-F7A9-8CB2-9806730B54E5",
        "SpeechResult=Repeat.",
        true,
    )
    .await
    .expect("Failed to execute request.");

    assert_that(&response).redirects_to("/meetings/de805daf-28e7-f7a9-8cb2-9806730b54e5");
}

#[sqlx::test(fixtures("schema", "teams", "books", "regions", "destinations", "meetings"))]
async fn meeting_post_redirects_to_voicemails_get_on_record(db: PgPool) {
    let response = post(
        db,
        "/meetings/DE805DAF-28E7-F7A9-8CB2-9806730B54E5",
        "SpeechResult=Record.",
        true,
    )
    .await
    .expect("Failed to execute request.");

    assert_that(&response).redirects_to("/voicemails/fixme");
}

#[sqlx::test(fixtures("schema", "teams", "books", "regions", "destinations", "meetings"))]
async fn meeting_post_redirects_to_hangup_on_end(db: PgPool) {
    let response = post(
        db,
        "/meetings/DE805DAF-28E7-F7A9-8CB2-9806730B54E5",
        "SpeechResult=End.",
        true,
    )
    .await
    .expect("Failed to execute request.");

    assert_that(&response).redirects_to("/hangup");
}
