# ApiPeriodV2010PeriodAccountPeriodCallPeriodCallFeedbackSummary

## Properties

Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**account_sid** | Option<**String**> | The unique id of the [Account](https://www.twilio.com/docs/iam/api/account) responsible for this resource. | [optional]
**call_count** | Option<**i32**> | The total number of calls. | [optional]
**call_feedback_count** | Option<**i32**> | The total number of calls with a feedback entry. | [optional]
**date_created** | Option<**String**> | The date that this resource was created, given in [RFC 2822](https://www.php.net/manual/en/class.datetime.php#datetime.constants.rfc2822) format. | [optional]
**date_updated** | Option<**String**> | The date that this resource was last updated, given in [RFC 2822](https://www.php.net/manual/en/class.datetime.php#datetime.constants.rfc2822) format. | [optional]
**end_date** | Option<[**String**](string.md)> | The last date for which feedback entries are included in this Feedback Summary, formatted as `YYYY-MM-DD` and specified in UTC. | [optional]
**include_subaccounts** | Option<**bool**> | Whether the feedback summary includes subaccounts; `true` if it does, otherwise `false`. | [optional]
**issues** | Option<[**Vec<serde_json::Value>**](serde_json::Value.md)> | A list of issues experienced during the call. The issues can be: `imperfect-audio`, `dropped-call`, `incorrect-caller-id`, `post-dial-delay`, `digits-not-captured`, `audio-latency`, or `one-way-audio`. | [optional]
**quality_score_average** | Option<**f32**> | The average QualityScore of the feedback entries. | [optional]
**quality_score_median** | Option<**f32**> | The median QualityScore of the feedback entries. | [optional]
**quality_score_standard_deviation** | Option<**f32**> | The standard deviation of the quality scores. | [optional]
**sid** | Option<**String**> | A 34 character string that uniquely identifies this resource. | [optional]
**start_date** | Option<[**String**](string.md)> | The first date for which feedback entries are included in this feedback summary, formatted as `YYYY-MM-DD` and specified in UTC. | [optional]
**status** | Option<[**crate::models::CallFeedbackSummaryEnumStatus**](call_feedback_summary_enum_status.md)> |  | [optional]

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


