mod helpers {
    include!("../helpers.rs");
}
use helpers::{post, RedirectTo};

use speculoos::prelude::*;
use sqlx::PgPool;

#[sqlx::test(fixtures("schema", "teams"))]
async fn post_recordings_redirects(db: PgPool) {
    for (speech_result, redirect) in [
        ("Prompts.", "/recordings/prompts"),
        ("Regions.", "/recordings/regions"),
        ("Destinations.", "/recordings/destinations"),
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
