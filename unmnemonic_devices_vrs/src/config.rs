use std::collections::HashMap;

#[derive(Debug, Default)]
pub struct Config {
    pub database_url: String,
    pub twilio_account_sid: String,
    pub twilio_api_key_sid: String,
    pub twilio_api_key_secret: String,
    pub twilio_url: String,
}

pub trait ConfigProvider {
    fn get_config(&self) -> &Config;
}

pub struct EnvVarProvider(Config);

impl EnvVarProvider {
    pub fn new(args: HashMap<String, String>) -> Self {
        let config = Config {
            database_url: args
                .get("DATABASE_URL")
                .expect("Missing database URL")
                .to_string(),
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
