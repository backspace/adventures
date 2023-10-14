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
pub struct ApiPeriodV2010PeriodAccountPeriodCallPeriodCallFeedbackSummary {
    /// The unique id of the [Account](https://www.twilio.com/docs/iam/api/account) responsible for this resource.
    #[serde(rename = "account_sid", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub account_sid: Option<Option<String>>,
    /// The total number of calls.
    #[serde(rename = "call_count", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub call_count: Option<Option<i32>>,
    /// The total number of calls with a feedback entry.
    #[serde(rename = "call_feedback_count", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub call_feedback_count: Option<Option<i32>>,
    /// The date that this resource was created, given in [RFC 2822](https://www.php.net/manual/en/class.datetime.php#datetime.constants.rfc2822) format.
    #[serde(rename = "date_created", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub date_created: Option<Option<String>>,
    /// The date that this resource was last updated, given in [RFC 2822](https://www.php.net/manual/en/class.datetime.php#datetime.constants.rfc2822) format.
    #[serde(rename = "date_updated", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub date_updated: Option<Option<String>>,
    /// The last date for which feedback entries are included in this Feedback Summary, formatted as `YYYY-MM-DD` and specified in UTC.
    #[serde(rename = "end_date", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub end_date: Option<Option<String>>,
    /// Whether the feedback summary includes subaccounts; `true` if it does, otherwise `false`.
    #[serde(rename = "include_subaccounts", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub include_subaccounts: Option<Option<bool>>,
    /// A list of issues experienced during the call. The issues can be: `imperfect-audio`, `dropped-call`, `incorrect-caller-id`, `post-dial-delay`, `digits-not-captured`, `audio-latency`, or `one-way-audio`.
    #[serde(rename = "issues", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub issues: Option<Option<Vec<serde_json::Value>>>,
    /// The average QualityScore of the feedback entries.
    #[serde(rename = "quality_score_average", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub quality_score_average: Option<Option<f32>>,
    /// The median QualityScore of the feedback entries.
    #[serde(rename = "quality_score_median", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub quality_score_median: Option<Option<f32>>,
    /// The standard deviation of the quality scores.
    #[serde(rename = "quality_score_standard_deviation", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub quality_score_standard_deviation: Option<Option<f32>>,
    /// A 34 character string that uniquely identifies this resource.
    #[serde(rename = "sid", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub sid: Option<Option<String>>,
    /// The first date for which feedback entries are included in this feedback summary, formatted as `YYYY-MM-DD` and specified in UTC.
    #[serde(rename = "start_date", default, with = "::serde_with::rust::double_option", skip_serializing_if = "Option::is_none")]
    pub start_date: Option<Option<String>>,
    #[serde(rename = "status", skip_serializing_if = "Option::is_none")]
    pub status: Option<crate::models::CallFeedbackSummaryEnumStatus>,
}

impl ApiPeriodV2010PeriodAccountPeriodCallPeriodCallFeedbackSummary {
    pub fn new() -> ApiPeriodV2010PeriodAccountPeriodCallPeriodCallFeedbackSummary {
        ApiPeriodV2010PeriodAccountPeriodCallPeriodCallFeedbackSummary {
            account_sid: None,
            call_count: None,
            call_feedback_count: None,
            date_created: None,
            date_updated: None,
            end_date: None,
            include_subaccounts: None,
            issues: None,
            quality_score_average: None,
            quality_score_median: None,
            quality_score_standard_deviation: None,
            sid: None,
            start_date: None,
            status: None,
        }
    }
}


