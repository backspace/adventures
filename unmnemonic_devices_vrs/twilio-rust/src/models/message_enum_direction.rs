/*
 * Twilio - Api
 *
 * This is the public Twilio REST API.
 *
 * The version of the OpenAPI document: 1.50.1
 * Contact: support@twilio.com
 * Generated by: https://openapi-generator.tech
 */


/// 
#[derive(Clone, Copy, Debug, Eq, PartialEq, Ord, PartialOrd, Hash, Serialize, Deserialize)]
pub enum MessageEnumDirection {
    #[serde(rename = "inbound")]
    Inbound,
    #[serde(rename = "outbound-api")]
    OutboundApi,
    #[serde(rename = "outbound-call")]
    OutboundCall,
    #[serde(rename = "outbound-reply")]
    OutboundReply,

}

impl ToString for MessageEnumDirection {
    fn to_string(&self) -> String {
        match self {
            Self::Inbound => String::from("inbound"),
            Self::OutboundApi => String::from("outbound-api"),
            Self::OutboundCall => String::from("outbound-call"),
            Self::OutboundReply => String::from("outbound-reply"),
        }
    }
}

impl Default for MessageEnumDirection {
    fn default() -> MessageEnumDirection {
        Self::Inbound
    }
}




