# \Api20100401FeedbackSummaryApi

All URIs are relative to *https://api.twilio.com*

Method | HTTP request | Description
------------- | ------------- | -------------
[**create_call_feedback_summary**](Api20100401FeedbackSummaryApi.md#create_call_feedback_summary) | **POST** /2010-04-01/Accounts/{AccountSid}/Calls/FeedbackSummary.json | 
[**delete_call_feedback_summary**](Api20100401FeedbackSummaryApi.md#delete_call_feedback_summary) | **DELETE** /2010-04-01/Accounts/{AccountSid}/Calls/FeedbackSummary/{Sid}.json | 
[**fetch_call_feedback_summary**](Api20100401FeedbackSummaryApi.md#fetch_call_feedback_summary) | **GET** /2010-04-01/Accounts/{AccountSid}/Calls/FeedbackSummary/{Sid}.json | 



## create_call_feedback_summary

> crate::models::ApiPeriodV2010PeriodAccountPeriodCallPeriodCallFeedbackSummary create_call_feedback_summary(account_sid, start_date, end_date, include_subaccounts, status_callback, status_callback_method)


Create a FeedbackSummary resource for a call

### Parameters


Name | Type | Description  | Required | Notes
------------- | ------------- | ------------- | ------------- | -------------
**account_sid** | **String** | The unique id of the [Account](https://www.twilio.com/docs/iam/api/account) responsible for this resource. | [required] |
**start_date** | **String** | Only include feedback given on or after this date. Format is `YYYY-MM-DD` and specified in UTC. | [required] |
**end_date** | **String** | Only include feedback given on or before this date. Format is `YYYY-MM-DD` and specified in UTC. | [required] |
**include_subaccounts** | Option<**bool**> | Whether to also include Feedback resources from all subaccounts. `true` includes feedback from all subaccounts and `false`, the default, includes feedback from only the specified account. |  |
**status_callback** | Option<**String**> | The URL that we will request when the feedback summary is complete. |  |
**status_callback_method** | Option<**String**> | The HTTP method (`GET` or `POST`) we use to make the request to the `StatusCallback` URL. |  |

### Return type

[**crate::models::ApiPeriodV2010PeriodAccountPeriodCallPeriodCallFeedbackSummary**](api.v2010.account.call.call_feedback_summary.md)

### Authorization

[accountSid_authToken](../README.md#accountSid_authToken)

### HTTP request headers

- **Content-Type**: application/x-www-form-urlencoded
- **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)


## delete_call_feedback_summary

> delete_call_feedback_summary(account_sid, sid)


Delete a FeedbackSummary resource from a call

### Parameters


Name | Type | Description  | Required | Notes
------------- | ------------- | ------------- | ------------- | -------------
**account_sid** | **String** | The unique id of the [Account](https://www.twilio.com/docs/iam/api/account) responsible for this resource. | [required] |
**sid** | **String** | A 34 character string that uniquely identifies this resource. | [required] |

### Return type

 (empty response body)

### Authorization

[accountSid_authToken](../README.md#accountSid_authToken)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)


## fetch_call_feedback_summary

> crate::models::ApiPeriodV2010PeriodAccountPeriodCallPeriodCallFeedbackSummary fetch_call_feedback_summary(account_sid, sid)


Fetch a FeedbackSummary resource from a call

### Parameters


Name | Type | Description  | Required | Notes
------------- | ------------- | ------------- | ------------- | -------------
**account_sid** | **String** | The unique id of the [Account](https://www.twilio.com/docs/iam/api/account) responsible for this resource. | [required] |
**sid** | **String** | A 34 character string that uniquely identifies this resource. | [required] |

### Return type

[**crate::models::ApiPeriodV2010PeriodAccountPeriodCallPeriodCallFeedbackSummary**](api.v2010.account.call.call_feedback_summary.md)

### Authorization

[accountSid_authToken](../README.md#accountSid_authToken)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

