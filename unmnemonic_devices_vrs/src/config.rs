// Adapted from https://dev.to/bdhobare/managing-application-config-in-rust-23ai
use std::collections::HashMap;

#[derive(Debug, Default)]
pub struct Config {
    pub auth: String,
    pub database_url: String,
    pub notification_number: String,
    pub root_url: String,
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
            database_url: args
                .get("DATABASE_URL")
                .expect("Missing database URL")
                .to_string(),
            notification_number: args
                .get("NOTIFICATION_NUMBER")
                .expect("Missing notification number")
                .to_string(),
            root_url: args.get("ROOT_URL").expect("Missing root URL").to_string(),
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
