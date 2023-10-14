# ApiPeriodV2010PeriodAccountPeriodCallPeriodCallFeedback

## Properties

Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**account_sid** | Option<**String**> | The unique id of the [Account](https://www.twilio.com/docs/iam/api/account) responsible for this resource. | [optional]
**date_created** | Option<**String**> | The date that this resource was created, given in [RFC 2822](https://www.php.net/manual/en/class.datetime.php#datetime.constants.rfc2822) format. | [optional]
**date_updated** | Option<**String**> | The date that this resource was last updated, given in [RFC 2822](https://www.php.net/manual/en/class.datetime.php#datetime.constants.rfc2822) format. | [optional]
**issues** | Option<[**Vec<crate::models::CallFeedbackEnumIssues>**](call_feedback_enum_issues.md)> | A list of issues experienced during the call. The issues can be: `imperfect-audio`, `dropped-call`, `incorrect-caller-id`, `post-dial-delay`, `digits-not-captured`, `audio-latency`, `unsolicited-call`, or `one-way-audio`. | [optional]
**quality_score** | Option<**i32**> | `1` to `5` quality score where `1` represents imperfect experience and `5` represents a perfect call. | [optional]
**sid** | Option<**String**> | A 34 character string that uniquely identifies this resource. | [optional]

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


