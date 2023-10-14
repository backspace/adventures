/*
 * Twilio - Api
 *
 * This is the public Twilio REST API.
 *
 * The version of the OpenAPI document: 1.50.1
 * Contact: support@twilio.com
 * Generated by: https://openapi-generator.tech
 */


use reqwest;

use crate::apis::ResponseContent;
use super::{Error, configuration};

/// struct for passing parameters to the method [`create_queue`]
#[derive(Clone, Debug)]
pub struct CreateQueueParams {
    /// The SID of the [Account](https://www.twilio.com/docs/iam/api/account) that will create the resource.
    pub account_sid: String,
    /// A descriptive string that you created to describe this resource. It can be up to 64 characters long.
    pub friendly_name: String,
    /// The maximum number of calls allowed to be in the queue. The default is 1000. The maximum is 5000.
    pub max_size: Option<i32>
}

/// struct for passing parameters to the method [`delete_queue`]
#[derive(Clone, Debug)]
pub struct DeleteQueueParams {
    /// The SID of the [Account](https://www.twilio.com/docs/iam/api/account) that created the Queue resource to delete.
    pub account_sid: String,
    /// The Twilio-provided string that uniquely identifies the Queue resource to delete
    pub sid: String
}

/// struct for passing parameters to the method [`fetch_queue`]
#[derive(Clone, Debug)]
pub struct FetchQueueParams {
    /// The SID of the [Account](https://www.twilio.com/docs/iam/api/account) that created the Queue resource to fetch.
    pub account_sid: String,
    /// The Twilio-provided string that uniquely identifies the Queue resource to fetch
    pub sid: String
}

/// struct for passing parameters to the method [`list_queue`]
#[derive(Clone, Debug)]
pub struct ListQueueParams {
    /// The SID of the [Account](https://www.twilio.com/docs/iam/api/account) that created the Queue resources to read.
    pub account_sid: String,
    /// How many resources to return in each list page. The default is 50, and the maximum is 1000.
    pub page_size: Option<i32>,
    /// The page index. This value is simply for client state.
    pub page: Option<i32>,
    /// The page token. This is provided by the API.
    pub page_token: Option<String>
}

/// struct for passing parameters to the method [`update_queue`]
#[derive(Clone, Debug)]
pub struct UpdateQueueParams {
    /// The SID of the [Account](https://www.twilio.com/docs/iam/api/account) that created the Queue resource to update.
    pub account_sid: String,
    /// The Twilio-provided string that uniquely identifies the Queue resource to update
    pub sid: String,
    /// A descriptive string that you created to describe this resource. It can be up to 64 characters long.
    pub friendly_name: Option<String>,
    /// The maximum number of calls allowed to be in the queue. The default is 1000. The maximum is 5000.
    pub max_size: Option<i32>
}


/// struct for typed errors of method [`create_queue`]
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum CreateQueueError {
    UnknownValue(serde_json::Value),
}

/// struct for typed errors of method [`delete_queue`]
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum DeleteQueueError {
    UnknownValue(serde_json::Value),
}

/// struct for typed errors of method [`fetch_queue`]
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum FetchQueueError {
    UnknownValue(serde_json::Value),
}

/// struct for typed errors of method [`list_queue`]
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum ListQueueError {
    UnknownValue(serde_json::Value),
}

/// struct for typed errors of method [`update_queue`]
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum UpdateQueueError {
    UnknownValue(serde_json::Value),
}


/// Create a queue
pub async fn create_queue(configuration: &configuration::Configuration, params: CreateQueueParams) -> Result<crate::models::ApiPeriodV2010PeriodAccountPeriodQueue, Error<CreateQueueError>> {
    let local_var_configuration = configuration;

    // unbox the parameters
    let account_sid = params.account_sid;
    let friendly_name = params.friendly_name;
    let max_size = params.max_size;


    let local_var_client = &local_var_configuration.client;

    let local_var_uri_str = format!("{}/2010-04-01/Accounts/{AccountSid}/Queues.json", local_var_configuration.base_path, AccountSid=crate::apis::urlencode(account_sid));
    let mut local_var_req_builder = local_var_client.request(reqwest::Method::POST, local_var_uri_str.as_str());

    if let Some(ref local_var_user_agent) = local_var_configuration.user_agent {
        local_var_req_builder = local_var_req_builder.header(reqwest::header::USER_AGENT, local_var_user_agent.clone());
    }
    if let Some(ref local_var_auth_conf) = local_var_configuration.basic_auth {
        local_var_req_builder = local_var_req_builder.basic_auth(local_var_auth_conf.0.to_owned(), local_var_auth_conf.1.to_owned());
    };
    let mut local_var_form_params = std::collections::HashMap::new();
    local_var_form_params.insert("FriendlyName", friendly_name.to_string());
    if let Some(local_var_param_value) = max_size {
        local_var_form_params.insert("MaxSize", local_var_param_value.to_string());
    }
    local_var_req_builder = local_var_req_builder.form(&local_var_form_params);

    let local_var_req = local_var_req_builder.build()?;
    let local_var_resp = local_var_client.execute(local_var_req).await?;

    let local_var_status = local_var_resp.status();
    let local_var_content = local_var_resp.text().await?;

    if !local_var_status.is_client_error() && !local_var_status.is_server_error() {
        serde_json::from_str(&local_var_content).map_err(Error::from)
    } else {
        let local_var_entity: Option<CreateQueueError> = serde_json::from_str(&local_var_content).ok();
        let local_var_error = ResponseContent { status: local_var_status, content: local_var_content, entity: local_var_entity };
        Err(Error::ResponseError(local_var_error))
    }
}

/// Remove an empty queue
pub async fn delete_queue(configuration: &configuration::Configuration, params: DeleteQueueParams) -> Result<(), Error<DeleteQueueError>> {
    let local_var_configuration = configuration;

    // unbox the parameters
    let account_sid = params.account_sid;
    let sid = params.sid;


    let local_var_client = &local_var_configuration.client;

    let local_var_uri_str = format!("{}/2010-04-01/Accounts/{AccountSid}/Queues/{Sid}.json", local_var_configuration.base_path, AccountSid=crate::apis::urlencode(account_sid), Sid=crate::apis::urlencode(sid));
    let mut local_var_req_builder = local_var_client.request(reqwest::Method::DELETE, local_var_uri_str.as_str());

    if let Some(ref local_var_user_agent) = local_var_configuration.user_agent {
        local_var_req_builder = local_var_req_builder.header(reqwest::header::USER_AGENT, local_var_user_agent.clone());
    }
    if let Some(ref local_var_auth_conf) = local_var_configuration.basic_auth {
        local_var_req_builder = local_var_req_builder.basic_auth(local_var_auth_conf.0.to_owned(), local_var_auth_conf.1.to_owned());
    };

    let local_var_req = local_var_req_builder.build()?;
    let local_var_resp = local_var_client.execute(local_var_req).await?;

    let local_var_status = local_var_resp.status();
    let local_var_content = local_var_resp.text().await?;

    if !local_var_status.is_client_error() && !local_var_status.is_server_error() {
        Ok(())
    } else {
        let local_var_entity: Option<DeleteQueueError> = serde_json::from_str(&local_var_content).ok();
        let local_var_error = ResponseContent { status: local_var_status, content: local_var_content, entity: local_var_entity };
        Err(Error::ResponseError(local_var_error))
    }
}

/// Fetch an instance of a queue identified by the QueueSid
pub async fn fetch_queue(configuration: &configuration::Configuration, params: FetchQueueParams) -> Result<crate::models::ApiPeriodV2010PeriodAccountPeriodQueue, Error<FetchQueueError>> {
    let local_var_configuration = configuration;

    // unbox the parameters
    let account_sid = params.account_sid;
    let sid = params.sid;


    let local_var_client = &local_var_configuration.client;

    let local_var_uri_str = format!("{}/2010-04-01/Accounts/{AccountSid}/Queues/{Sid}.json", local_var_configuration.base_path, AccountSid=crate::apis::urlencode(account_sid), Sid=crate::apis::urlencode(sid));
    let mut local_var_req_builder = local_var_client.request(reqwest::Method::GET, local_var_uri_str.as_str());

    if let Some(ref local_var_user_agent) = local_var_configuration.user_agent {
        local_var_req_builder = local_var_req_builder.header(reqwest::header::USER_AGENT, local_var_user_agent.clone());
    }
    if let Some(ref local_var_auth_conf) = local_var_configuration.basic_auth {
        local_var_req_builder = local_var_req_builder.basic_auth(local_var_auth_conf.0.to_owned(), local_var_auth_conf.1.to_owned());
    };

    let local_var_req = local_var_req_builder.build()?;
    let local_var_resp = local_var_client.execute(local_var_req).await?;

    let local_var_status = local_var_resp.status();
    let local_var_content = local_var_resp.text().await?;

    if !local_var_status.is_client_error() && !local_var_status.is_server_error() {
        serde_json::from_str(&local_var_content).map_err(Error::from)
    } else {
        let local_var_entity: Option<FetchQueueError> = serde_json::from_str(&local_var_content).ok();
        let local_var_error = ResponseContent { status: local_var_status, content: local_var_content, entity: local_var_entity };
        Err(Error::ResponseError(local_var_error))
    }
}

/// Retrieve a list of queues belonging to the account used to make the request
pub async fn list_queue(configuration: &configuration::Configuration, params: ListQueueParams) -> Result<crate::models::ListQueueResponse, Error<ListQueueError>> {
    let local_var_configuration = configuration;

    // unbox the parameters
    let account_sid = params.account_sid;
    let page_size = params.page_size;
    let page = params.page;
    let page_token = params.page_token;


    let local_var_client = &local_var_configuration.client;

    let local_var_uri_str = format!("{}/2010-04-01/Accounts/{AccountSid}/Queues.json", local_var_configuration.base_path, AccountSid=crate::apis::urlencode(account_sid));
    let mut local_var_req_builder = local_var_client.request(reqwest::Method::GET, local_var_uri_str.as_str());

    if let Some(ref local_var_str) = page_size {
        local_var_req_builder = local_var_req_builder.query(&[("PageSize", &local_var_str.to_string())]);
    }
    if let Some(ref local_var_str) = page {
        local_var_req_builder = local_var_req_builder.query(&[("Page", &local_var_str.to_string())]);
    }
    if let Some(ref local_var_str) = page_token {
        local_var_req_builder = local_var_req_builder.query(&[("PageToken", &local_var_str.to_string())]);
    }
    if let Some(ref local_var_user_agent) = local_var_configuration.user_agent {
        local_var_req_builder = local_var_req_builder.header(reqwest::header::USER_AGENT, local_var_user_agent.clone());
    }
    if let Some(ref local_var_auth_conf) = local_var_configuration.basic_auth {
        local_var_req_builder = local_var_req_builder.basic_auth(local_var_auth_conf.0.to_owned(), local_var_auth_conf.1.to_owned());
    };

    let local_var_req = local_var_req_builder.build()?;
    let local_var_resp = local_var_client.execute(local_var_req).await?;

    let local_var_status = local_var_resp.status();
    let local_var_content = local_var_resp.text().await?;

    if !local_var_status.is_client_error() && !local_var_status.is_server_error() {
        serde_json::from_str(&local_var_content).map_err(Error::from)
    } else {
        let local_var_entity: Option<ListQueueError> = serde_json::from_str(&local_var_content).ok();
        let local_var_error = ResponseContent { status: local_var_status, content: local_var_content, entity: local_var_entity };
        Err(Error::ResponseError(local_var_error))
    }
}

/// Update the queue with the new parameters
pub async fn update_queue(configuration: &configuration::Configuration, params: UpdateQueueParams) -> Result<crate::models::ApiPeriodV2010PeriodAccountPeriodQueue, Error<UpdateQueueError>> {
    let local_var_configuration = configuration;

    // unbox the parameters
    let account_sid = params.account_sid;
    let sid = params.sid;
    let friendly_name = params.friendly_name;
    let max_size = params.max_size;


    let local_var_client = &local_var_configuration.client;

    let local_var_uri_str = format!("{}/2010-04-01/Accounts/{AccountSid}/Queues/{Sid}.json", local_var_configuration.base_path, AccountSid=crate::apis::urlencode(account_sid), Sid=crate::apis::urlencode(sid));
    let mut local_var_req_builder = local_var_client.request(reqwest::Method::POST, local_var_uri_str.as_str());

    if let Some(ref local_var_user_agent) = local_var_configuration.user_agent {
        local_var_req_builder = local_var_req_builder.header(reqwest::header::USER_AGENT, local_var_user_agent.clone());
    }
    if let Some(ref local_var_auth_conf) = local_var_configuration.basic_auth {
        local_var_req_builder = local_var_req_builder.basic_auth(local_var_auth_conf.0.to_owned(), local_var_auth_conf.1.to_owned());
    };
    let mut local_var_form_params = std::collections::HashMap::new();
    if let Some(local_var_param_value) = friendly_name {
        local_var_form_params.insert("FriendlyName", local_var_param_value.to_string());
    }
    if let Some(local_var_param_value) = max_size {
        local_var_form_params.insert("MaxSize", local_var_param_value.to_string());
    }
    local_var_req_builder = local_var_req_builder.form(&local_var_form_params);

    let local_var_req = local_var_req_builder.build()?;
    let local_var_resp = local_var_client.execute(local_var_req).await?;

    let local_var_status = local_var_resp.status();
    let local_var_content = local_var_resp.text().await?;

    if !local_var_status.is_client_error() && !local_var_status.is_server_error() {
        serde_json::from_str(&local_var_content).map_err(Error::from)
    } else {
        let local_var_entity: Option<UpdateQueueError> = serde_json::from_str(&local_var_content).ok();
        let local_var_error = ResponseContent { status: local_var_status, content: local_var_content, entity: local_var_entity };
        Err(Error::ResponseError(local_var_error))
    }
}

