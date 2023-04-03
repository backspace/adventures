use axum::{
    body::{Bytes, Full},
    extract::Query,
    extract::State,
    response::{Redirect, Response},
    Form,
};
use serde::Deserialize;

use crate::AppState;

#[derive(Deserialize)]
pub struct RootParams {
    begun: Option<String>,
}

pub async fn get_root(
    State(state): State<AppState>,
    params: Query<RootParams>,
) -> Response<Full<Bytes>> {
    let settings = sqlx::query!("SELECT begun FROM settings LIMIT 1")
        .fetch_one(&state.db)
        .await
        .expect("Failed to fetch settings");

    let body = if settings.begun.unwrap() || params.begun.is_some() {
        r#"
        <Response>
            <Say>Has it begun?</Say>
        </Response>
        "#
    } else {
        r#"
        <Response>
            <Gather input="speech" hints="begun, jortle, tortle">
                <Say>Hello. Welcome to unmnemonic devices. Say something?</Say>
            </Gather>
            <Say>We didn't hear anything. Goodbye.</Say>
        </Response>
        "#
    };

    Response::builder()
        .header("content-type", "application/xml")
        .body(Full::from(body))
        .unwrap()
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct RootForm {
    speech_result: String,
}

pub async fn post_root(Form(form): Form<RootForm>) -> Redirect {
    if form.speech_result == "Begun." {
        Redirect::to("/?begun")
    } else {
        Redirect::to("/")
    }
}
