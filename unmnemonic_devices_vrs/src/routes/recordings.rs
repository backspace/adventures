use axum::{
    extract::State,
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;
use serde::Serialize;

use crate::{render_xml::RenderXml, twilio_form::TwilioForm, AppState};

#[axum_macros::debug_handler]
pub async fn get_recordings(Key(key): Key, State(state): State<AppState>) -> impl IntoResponse {
    RenderXml(
        key,
        state.engine,
        state.mutable_prompts.lock().unwrap().to_string(),
        (),
    )
}

#[axum_macros::debug_handler]
pub async fn post_recordings(Form(form): Form<TwilioForm>) -> Redirect {
    if form.speech_result == "prompts" {
        Redirect::to("/recordings/prompts")
    } else if form.speech_result == "destinations" {
        Redirect::to("/recordings/destinations")
    } else if form.speech_result == "regions" {
        Redirect::to("/recordings/regions")
    } else if form.speech_result == "teams" {
        Redirect::to("/recordings/teams")
    } else {
        Redirect::to("/")
    }
}

#[derive(Serialize)]
struct Confirm {
    voicepass: String,
}

#[axum_macros::debug_handler]
pub async fn get_recordings_confirm(
    Key(key): Key,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let recordings_voicepass = state.config.recordings_voicepass.to_string();

    RenderXml(
        key,
        state.engine,
        state.mutable_prompts.lock().unwrap().to_string(),
        Confirm {
            voicepass: recordings_voicepass,
        },
    )
}

#[axum_macros::debug_handler]
pub async fn post_recordings_confirm(
    State(state): State<AppState>,
    Form(form): Form<TwilioForm>,
) -> Redirect {
    let recordings_voicepass = state.config.recordings_voicepass;

    if form.speech_result == recordings_voicepass {
        Redirect::to("/recordings")
    } else {
        Redirect::to("/recordings/voicepass-incorrect")
    }
}

#[axum_macros::debug_handler]
pub async fn get_recordings_voicepass_incorrect(
    Key(key): Key,
    State(state): State<AppState>,
) -> impl IntoResponse {
    RenderXml(
        key,
        state.engine,
        state.mutable_prompts.lock().unwrap().to_string(),
        (),
    )
}
