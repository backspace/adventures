# default_api

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
****](default_api.md#) | **POST** /answers | Create a new answer
****](default_api.md#) | **GET** /games/{id} | Fetch a game
****](default_api.md#) | **POST** /games | Create a new game


# ****
> models::Answer (answer_input)
Create a new answer

### Required Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
  **answer_input** | [**AnswerInput**](AnswerInput.md)|  | 

### Return type

[**models::Answer**](Answer.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# ****
> models::GamesIdGet200Response (id)
Fetch a game

### Required Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
  **id** | [****](.md)|  | 

### Return type

[**models::GamesIdGet200Response**](_games__id__get_200_response.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# ****
> models::GamesPost201Response (game_input, optional)
Create a new game

### Required Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
  **game_input** | [**GameInput**](GameInput.md)|  | 
 **optional** | **map[string]interface{}** | optional parameters | nil if no parameters

### Optional Parameters
Optional parameters are passed through a map[string]interface{}.

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **game_input** | [**GameInput**](GameInput.md)|  | 
 **concept** | **String**| Optional concept for the game | 
 **incarnation_filter_left_square_bracket_concept_right_square_bracket** | **String**| Filter incarnations by concept | 

### Return type

[**models::GamesPost201Response**](_games_post_201_response.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

