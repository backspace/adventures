// Adapted from https://dev.to/bdhobare/managing-application-config-in-rust-23ai
use std::collections::HashMap;
use url::Url;

#[derive(Debug)]
pub struct Config {
    pub auth: String,
    pub database_url: Url,
    pub notification_number: String,
    pub supervisor_number: String,
    pub root_url: Url,
    pub twilio_account_sid: String,
    pub twilio_api_key_sid: String,
    pub twilio_api_key_secret: String,
    pub twilio_number: String,
    pub twilio_url: String,
}

pub trait ConfigProvider {
    fn get_config(&self) -> &Config;
}

pub struct EnvVarProvider(Config);

impl EnvVarProvider {
    pub fn new(args: HashMap<String, String>) -> Self {
        let config = Config {
            auth: args.get("AUTH").expect("Missing auth").to_string(),
            database_url: Url::parse(args.get("DATABASE_URL").expect("Missing database URL"))
                .expect("Unable to parse DATABASE_URL as a URL"),
            notification_number: args
                .get("NOTIFICATION_NUMBER")
                .expect("Missing notification number")
                .to_string(),
            supervisor_number: args
                .get("SUPERVISOR_NUMBER")
                .expect("Missing supervisor number")
                .to_string(),
            root_url: Url::parse(args.get("ROOT_URL").expect("Missing root URL"))
                .expect("Unable to parse ROOT_URL as a URL"),
            twilio_account_sid: args
                .get("TWILIO_ACCOUNT_SID")
                .expect("Missing Twilio account SID")
                .to_string(),
            twilio_api_key_sid: args
                .get("TWILIO_API_KEY_SID")
                .expect("Missing Twilio API key SID")
                .to_string(),
            twilio_api_key_secret: args
                .get("TWILIO_API_KEY_SECRET")
                .expect("Missing Twilio API key secret")
                .to_string(),
            twilio_number: args
                .get("TWILIO_NUMBER")
                .expect("Missing Twilio number")
                .to_string(),
            twilio_url: "https://api.twilio.com".to_string(),
        };

        EnvVarProvider(config)
    }
}

impl ConfigProvider for EnvVarProvider {
    fn get_config(&self) -> &Config {
        &self.0
    }
}

impl Default for EnvVarProvider {
    fn default() -> Self {
        Self::new(HashMap::new())
    }
}
