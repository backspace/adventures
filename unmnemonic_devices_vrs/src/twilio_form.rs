use serde::Deserialize;

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct TwilioForm {
    pub speech_result: String,
}
