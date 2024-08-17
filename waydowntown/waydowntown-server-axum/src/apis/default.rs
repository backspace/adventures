use async_trait::async_trait;
use axum::extract::*;
use axum_extra::extract::{CookieJar, Multipart};
use bytes::Bytes;
use http::Method;
use serde::{Deserialize, Serialize};

use crate::{models, types::*};

#[derive(Debug, PartialEq, Serialize, Deserialize)]
#[must_use]
#[allow(clippy::large_enum_variant)]
pub enum AnswersPostResponse {
    /// Successfully created answer
    Status201_SuccessfullyCreatedAnswer
    (models::Answer)
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
#[must_use]
#[allow(clippy::large_enum_variant)]
pub enum GamesIdGetResponse {
    /// Successfully fetched game
    Status200_SuccessfullyFetchedGame
    (models::GamesIdGet200Response)
}

#[derive(Debug, PartialEq, Serialize, Deserialize)]
#[must_use]
#[allow(clippy::large_enum_variant)]
pub enum GamesPostResponse {
    /// Successfully created game
    Status201_SuccessfullyCreatedGame
    (models::GamesPost201Response)
}


/// Default
#[async_trait]
#[allow(clippy::ptr_arg)]
pub trait Default {
    /// Create a new answer.
    ///
    /// AnswersPost - POST /answers
    async fn answers_post(
    &self,
    method: Method,
    host: Host,
    cookies: CookieJar,
            body: models::AnswerInput,
    ) -> Result<AnswersPostResponse, String>;

    /// Fetch a game.
    ///
    /// GamesIdGet - GET /games/{id}
    async fn games_id_get(
    &self,
    method: Method,
    host: Host,
    cookies: CookieJar,
      path_params: models::GamesIdGetPathParams,
    ) -> Result<GamesIdGetResponse, String>;

    /// Create a new game.
    ///
    /// GamesPost - POST /games
    async fn games_post(
    &self,
    method: Method,
    host: Host,
    cookies: CookieJar,
      query_params: models::GamesPostQueryParams,
            body: models::GameInput,
    ) -> Result<GamesPostResponse, String>;
}
