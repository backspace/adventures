/*
 * Twilio - Api
 *
 * This is the public Twilio REST API.
 *
 * The version of the OpenAPI document: 1.50.1
 * Contact: support@twilio.com
 * Generated by: https://openapi-generator.tech
 */




#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ApiPeriodV2010PeriodAccountPeriodIncomingPhoneNumberPeriodIncomingPhoneNumberAssignedAddOnPeriodIncomingPhoneNumberAssignedAddOnExtension {
    /// The unique string that that we created to identify the resource.
    #[serde(rename = "sid", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub sid: Option<Option<String>>,
    /// The SID of the [Account](https://www.twilio.com/docs/iam/api/account) that created the resource.
    #[serde(rename = "account_sid", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub account_sid: Option<Option<String>>,
    /// The SID of the Phone Number to which the Add-on is assigned.
    #[serde(rename = "resource_sid", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub resource_sid: Option<Option<String>>,
    /// The SID that uniquely identifies the assigned Add-on installation.
    #[serde(rename = "assigned_add_on_sid", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub assigned_add_on_sid: Option<Option<String>>,
    /// The string that you assigned to describe the resource.
    #[serde(rename = "friendly_name", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub friendly_name: Option<Option<String>>,
    /// A string that you assigned to describe the Product this Extension is used within.
    #[serde(rename = "product_name", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub product_name: Option<Option<String>>,
    /// An application-defined string that uniquely identifies the resource. It can be used in place of the resource's `sid` in the URL to address the resource.
    #[serde(rename = "unique_name", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub unique_name: Option<Option<String>>,
    /// The URI of the resource, relative to `https://api.twilio.com`.
    #[serde(rename = "uri", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub uri: Option<Option<String>>,
    /// Whether the Extension will be invoked.
    #[serde(rename = "enabled", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub enabled: Option<Option<bool>>,
}

impl ApiPeriodV2010PeriodAccountPeriodIncomingPhoneNumberPeriodIncomingPhoneNumberAssignedAddOnPeriodIncomingPhoneNumberAssignedAddOnExtension {
    pub fn new() -> ApiPeriodV2010PeriodAccountPeriodIncomingPhoneNumberPeriodIncomingPhoneNumberAssignedAddOnPeriodIncomingPhoneNumberAssignedAddOnExtension {
        ApiPeriodV2010PeriodAccountPeriodIncomingPhoneNumberPeriodIncomingPhoneNumberAssignedAddOnPeriodIncomingPhoneNumberAssignedAddOnExtension {
            sid: None,
            account_sid: None,
            resource_sid: None,
            assigned_add_on_sid: None,
            friendly_name: None,
            product_name: None,
            unique_name: None,
            uri: None,
            enabled: None,
        }
    }
}


