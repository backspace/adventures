# \Api20100401SafelistApi

All URIs are relative to *https://api.twilio.com*

Method | HTTP request | Description
------------- | ------------- | -------------
[**create_safelist**](Api20100401SafelistApi.md#create_safelist) | **POST** /2010-04-01/SafeList/Numbers.json | 
[**delete_safelist**](Api20100401SafelistApi.md#delete_safelist) | **DELETE** /2010-04-01/SafeList/Numbers.json | 
[**fetch_safelist**](Api20100401SafelistApi.md#fetch_safelist) | **GET** /2010-04-01/SafeList/Numbers.json | 



## create_safelist

> crate::models::ApiPeriodV2010PeriodSafelist create_safelist(phone_number)


Add a new phone number to SafeList.

### Parameters


Name | Type | Description  | Required | Notes
------------- | ------------- | ------------- | ------------- | -------------
**phone_number** | **String** | The phone number to be added in SafeList. Phone numbers must be in [E.164 format](https://www.twilio.com/docs/glossary/what-e164). | [required] |

### Return type

[**crate::models::ApiPeriodV2010PeriodSafelist**](api.v2010.safelist.md)

### Authorization

[accountSid_authToken](../README.md#accountSid_authToken)

### HTTP request headers

- **Content-Type**: application/x-www-form-urlencoded
- **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)


## delete_safelist

> delete_safelist(phone_number)


Remove a phone number from SafeList.

### Parameters


Name | Type | Description  | Required | Notes
------------- | ------------- | ------------- | ------------- | -------------
**phone_number** | Option<**String**> | The phone number to be removed from SafeList. Phone numbers must be in [E.164 format](https://www.twilio.com/docs/glossary/what-e164). |  |

### Return type

 (empty response body)

### Authorization

[accountSid_authToken](../README.md#accountSid_authToken)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)


## fetch_safelist

> crate::models::ApiPeriodV2010PeriodSafelist fetch_safelist(phone_number)


Check if a phone number exists in SafeList.

### Parameters


Name | Type | Description  | Required | Notes
------------- | ------------- | ------------- | ------------- | -------------
**phone_number** | Option<**String**> | The phone number to be fetched from SafeList. Phone numbers must be in [E.164 format](https://www.twilio.com/docs/glossary/what-e164). |  |

### Return type

[**crate::models::ApiPeriodV2010PeriodSafelist**](api.v2010.safelist.md)

### Authorization

[accountSid_authToken](../README.md#accountSid_authToken)

### HTTP request headers

- **Content-Type**: Not defined
- **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

