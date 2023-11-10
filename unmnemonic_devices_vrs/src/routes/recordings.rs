use axum::{
    extract::State,
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;

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
    } else if form.speech_result == "regions" {
        Redirect::to("/recordings/regions")
    } else if form.speech_result == "destinations" {
        Redirect::to("/recordings/destinations")
    } else {
        Redirect::to("/")
    }
}
