use serde::de::{self, Visitor};
use serde::{Deserialize, Deserializer};
use std::fmt;

struct StringVisitor;

impl<'de> Visitor<'de> for StringVisitor {
    type Value = String;

    fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
        formatter.write_str("a string in Twilio’s SpeechResult format")
    }

    fn visit_str<E>(self, value: &str) -> Result<Self::Value, E>
    where
        E: de::Error,
    {
        Ok(unsentence_string(value))
    }
}

fn unsentence_string(input: &str) -> String {
    let cleaned = input.to_lowercase().replace(&['?', '.', ','][..], "");

    println!("SpeechResult=`{:?}`, speech_result=`{:?}`", input, cleaned);

    cleaned
}

fn deserialise_twilio_speech_result<'de, D>(deserialiser: D) -> Result<String, D::Error>
where
    D: Deserializer<'de>,
{
    deserialiser.deserialize_string(StringVisitor)
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "PascalCase")]
pub struct TwilioForm {
    #[serde(deserialize_with = "deserialise_twilio_speech_result")]
    pub speech_result: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct TwilioRecordingForm {
    pub recording_url: String,
}
