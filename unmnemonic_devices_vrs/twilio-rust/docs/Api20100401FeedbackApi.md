# \Api20100401FeedbackApi

All URIs are relative to *https://api.twilio.com*

Method | HTTP request | Description
------------- | ------------- | -------------
[**create_message_feedback**](Api20100401FeedbackApi.md#create_message_feedback) | **POST** /2010-04-01/Accounts/{AccountSid}/Messages/{MessageSid}/Feedback.json | 
[**fetch_call_feedback**](Api20100401FeedbackApi.md#fetch_call_feedback) | **GET** /2010-04-01/Accounts/{AccountSid}/Calls/{CallSid}/Feedback.json | 
[**update_call_feedback**](Api20100401FeedbackApi.md#update_call_feedback) | **POST** /2010-04-01/Accounts/{AccountSid}/Calls/{CallSid}/Feedback.json | 



## create_message_feedback

> crate::models::ApiPeriodV2010PeriodAccountPeriodMessagePeriodMessageFeedback create_message_feedback(account_sid, message_sid, outcome)


Create Message Feedback to confirm a tracked user action was performed by the recipient of the associated Message

### Parameters


Name | Type | Description  | Required | Notes
------------- | ------------- | ------------- | ------------- | -------------
**account_sid** | **String** | The SID of the [Account](https://www.twilio.com/docs/iam/api/account) associated with the Message resource for which to create MessageFeedback. | [required] |
**message_sid** | **String** | The SID of the Message resource for which to create MessageFeedback. | [required] |
**outcome** | Option<**crate::models::MessageFeedbackEnumOutcome**> |  |  |

### Return type

[**crate::models::ApiPeriodV2010PeriodAccountPeriodMessagePeriodMessageFeedback**](api.v2010.account.message.message_feedback.md)

### Authorization

[accountSid_authToken](../README.md#accountSid_authToken)

### HTTP request headers

- **Content-Type**: application/x-www-form-urlencoded
- **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)


## fetch_call_feedback

> crate::models::ApiPeriodV2010PeriodAccountPeriodCallPeriodCallFeedback fetch_call_feedback(account_sid, call_sid)


Fetch a Feedback resource from a call

### Parameters


Name | Type | Description  | Required | Notes
------------- | ------------- | ------------- | ------------- | -------------
**account_sid** | **String** | The unique id of the [Account](https://www.twilio.com/docs/iam/api/account) responsible for this resource. | [required] |
**call_sid** | **String** | The call sid that uniquely identifies the call | [required] |

### Return type

[**crate::models::ApiPeriodV2010PeriodAccountPeriodCallPeriodCallFeedback**](api.v2010.account.call.call_feedback.md)

### Authorization

[accountSid_authToken](../README.md#accountSid_authToken)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)


## update_call_feedback

> crate::models::ApiPeriodV2010PeriodAccountPeriodCallPeriodCallFeedback update_call_feedback(account_sid, call_sid, quality_score, issue)


Update a Feedback resource for a call

### Parameters


Name | Type | Description  | Required | Notes
------------- | ------------- | ------------- | ------------- | -------------
**account_sid** | **String** | The unique id of the [Account](https://www.twilio.com/docs/iam/api/account) responsible for this resource. | [required] |
**call_sid** | **String** | The call sid that uniquely identifies the call | [required] |
**quality_score** | Option<**i32**> | The call quality expressed as an integer from `1` to `5` where `1` represents very poor call quality and `5` represents a perfect call. |  |
**issue** | Option<[**Vec<crate::models::CallFeedbackEnumIssues>**](crate::models::CallFeedbackEnumIssues.md)> | One or more issues experienced during the call. The issues can be: `imperfect-audio`, `dropped-call`, `incorrect-caller-id`, `post-dial-delay`, `digits-not-captured`, `audio-latency`, `unsolicited-call`, or `one-way-audio`. |  |

### Return type

[**crate::models::ApiPeriodV2010PeriodAccountPeriodCallPeriodCallFeedback**](api.v2010.account.call.call_feedback.md)

### Authorization

[accountSid_authToken](../README.md#accountSid_authToken)

### HTTP request headers

- **Content-Type**: application/x-www-form-urlencoded
- **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

