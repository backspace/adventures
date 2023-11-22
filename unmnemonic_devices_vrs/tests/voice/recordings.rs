use crate::common;
use common::helpers::{post, RedirectTo};

use speculoos::prelude::*;
use sqlx::PgPool;

#[sqlx::test(fixtures("schema", "teams"))]
async fn post_recordings_redirects(db: PgPool) {
    for (speech_result, redirect) in [
        ("Prompts.", "/recordings/prompts"),
        ("Destinations.", "/recordings/destinations"),
        ("Regions.", "/recordings/regions"),
        ("Teams.", "/recordings/teams"),
    ] {
        let response = post(
            db.clone(),
            "/recordings",
            // Twilio editorialises punctuation and always capitalises.
            &format!("SpeechResult={}", speech_result),
            true,
        )
        .await
        .expect("Failed to execute request.");

        assert_that(&response).redirects_to(redirect);
    }
}
