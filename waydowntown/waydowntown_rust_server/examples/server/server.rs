//! Main library entry point for waydowntown_server implementation.

#![allow(unused_imports)]

use async_trait::async_trait;
use futures::{future, Stream, StreamExt, TryFutureExt, TryStreamExt};
use hyper::server::conn::Http;
use hyper::service::Service;
use log::info;
use std::future::Future;
use std::marker::PhantomData;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use std::task::{Context, Poll};
use swagger::{Has, XSpanIdString, Nullable};
use swagger::auth::MakeAllowAllAuthenticator;
use swagger::EmptyContext;
use tokio::net::TcpListener;
use sqlx::postgres::PgPool;

#[cfg(not(any(target_os = "macos", target_os = "windows", target_os = "ios")))]
use openssl::ssl::{Ssl, SslAcceptor, SslAcceptorBuilder, SslFiletype, SslMethod};

use waydowntown_server::models;

/// Builds an SSL implementation for Simple HTTPS from some hard-coded file names
pub async fn create(addr: &str, https: bool, database_url: &str) -> Result<(), Box<dyn Error>> {
    let addr = addr.parse().expect("Failed to parse bind address");

    // Establish database connection
    let db_pool = PgPool::connect(database_url).await?;

    let server = Server::new(db_pool);

    let service = MakeService::new(server);

    // This pushes a fourth layer of the middleware-stack even though Swagger assumes only three levels.
    // This fourth layer creates an accept-all policy, hower the example-code already acchieves the same via a Bearer-token with full permissions, so next line is not needed (anymore).
    // let service = MakeAllowAllAuthenticator::new(service, "cosmo");

    #[allow(unused_mut)]
    let mut service =
        waydowntown_server::server::context::MakeAddContext::<_, EmptyContext>::new(
            service
        );

    if https {
        #[cfg(any(target_os = "macos", target_os = "windows", target_os = "ios"))]
        {
            unimplemented!("SSL is not implemented for the examples on MacOS, Windows or iOS");
        }

        #[cfg(not(any(target_os = "macos", target_os = "windows", target_os = "ios")))]
        {
            let mut ssl = SslAcceptor::mozilla_intermediate_v5(SslMethod::tls()).expect("Failed to create SSL Acceptor");

            // Server authentication
            ssl.set_private_key_file("examples/server-key.pem", SslFiletype::PEM).expect("Failed to set private key");
            ssl.set_certificate_chain_file("examples/server-chain.pem").expect("Failed to set certificate chain");
            ssl.check_private_key().expect("Failed to check private key");

            let tls_acceptor = ssl.build();
            let tcp_listener = TcpListener::bind(&addr).await.unwrap();

            info!("Starting a server (with https)");
            loop {
                if let Ok((tcp, _)) = tcp_listener.accept().await {
                    let ssl = Ssl::new(tls_acceptor.context()).unwrap();
                    let addr = tcp.peer_addr().expect("Unable to get remote address");
                    let service = service.call(addr);

                    tokio::spawn(async move {
                        let tls = tokio_openssl::SslStream::new(ssl, tcp).map_err(|_| ())?;
                        let service = service.await.map_err(|_| ())?;

                        Http::new()
                            .serve_connection(tls, service)
                            .await
                            .map_err(|_| ())
                    });
                }
            }
        }
    } else {
        info!("Starting a server (over http, so no TLS)");
        // Using HTTP
        hyper::server::Server::bind(&addr).serve(service).await?;
        Ok(())
    }
}

#[derive(Clone)]
pub struct Server<C> {
    marker: PhantomData<C>,
    db: PgPool,
}

impl<C> Server<C> {
    pub fn new(db: PgPool) -> Self {
        Server{marker: PhantomData, db}
    }
}


use jsonwebtoken::{decode, encode, errors::Error as JwtError, Algorithm, DecodingKey, EncodingKey, Header, TokenData, Validation};
use serde::{Deserialize, Serialize};
use swagger::auth::Authorization;
use crate::server_auth;


use waydowntown_server::{
    Api,
    AnswersPostResponse,
    GamesIdGetResponse,
    GamesPostResponse,
};
use waydowntown_server::server::MakeService;
use std::error::Error;
use swagger::ApiError;
struct CustomApiError(String);

impl From<String> for CustomApiError {
    fn from(error: String) -> Self {
        CustomApiError(error)
    }
}

impl From<CustomApiError> for ApiError {
    fn from(error: CustomApiError) -> Self {
        ApiError(error.0)
    }
}

#[async_trait]
impl<C> Api<C> for Server<C> where C: Has<XSpanIdString> + Send + Sync
{
    /// Create a new answer
    async fn answers_post(
        &self,
        answer_input: models::AnswerInput,
        context: &C) -> Result<AnswersPostResponse, ApiError>
    {
        info!("answers_post({:?}) - X-Span-ID: {:?}", answer_input, context.get().0.clone());
        Err(ApiError("Api-Error: Operation is NOT implemented".into()))
    }

    /// Fetch a game
    async fn games_id_get(
        &self,
        id: uuid::Uuid,
        _context: &C) -> Result<GamesIdGetResponse, ApiError>
    {
        // Fetch the game and its related data
        let result = sqlx::query!(
            r#"
            WITH RECURSIVE region_hierarchy AS (
                SELECT r.id, r.name, r.description, r.parent_id
                FROM waydowntown.regions r
                JOIN waydowntown.incarnations i ON i.region_id = r.id
                JOIN waydowntown.games g ON g.incarnation_id = i.id
                WHERE g.id = $1

                UNION ALL

                SELECT r.id, r.name, r.description, r.parent_id
                FROM waydowntown.regions r
                JOIN region_hierarchy rh ON r.id = rh.parent_id
            )
            SELECT
                g.id AS game_id,
                g.winner_answer_id IS NOT NULL AS game_complete,
                i.id AS incarnation_id,
                i.concept AS incarnation_concept,
                i.mask AS incarnation_mask,
                i.answer AS incarnation_answer,
                i.answers AS incarnation_answers,
                r.id AS region_id,
                r.name AS region_name,
                r.description AS region_description,
                p.id AS parent_region_id,
                p.name AS parent_region_name,
                p.description AS parent_region_description
            FROM waydowntown.games g
            JOIN waydowntown.incarnations i ON g.incarnation_id = i.id
            JOIN region_hierarchy r ON i.region_id = r.id
            LEFT JOIN region_hierarchy p ON r.parent_id = p.id
            WHERE g.id = $1
            "#,
            id
        )
        .fetch_one(&self.db)
        .await
        .map_err(|e| CustomApiError(e.to_string()))?;

        // Construct the Game object
        let game = models::Game {
            id: Some(result.game_id),
            attributes: Some(models::GameAttributes {
                complete: result.game_complete,
            }),
            relationships: Some(models::GameRelationships {
                incarnation: Some(models::GameRelationshipsIncarnation {
                    data: Some(models::GameRelationshipsIncarnationData {
                        id: Some(result.incarnation_id),
                    }),
                }),
                winner_answer: Some(models::GameRelationshipsWinnerAnswer {
                    data: None, // We're not fetching the winner answer in this query
                }),
            }),
        };

        // Construct the Incarnation object
        let incarnation = models::Incarnation {
            id: Some(result.incarnation_id),
            attributes: Some(models::IncarnationAttributes {
                concept: result.incarnation_concept.clone(),
                mask: result.incarnation_mask.clone(),
                answer: result.incarnation_answer.clone(),
                answers: result.incarnation_answers.clone(),
            }),
            relationships: Some(models::IncarnationRelationships {
                region: Some(models::IncarnationRelationshipsRegion {
                    data: Some(models::IncarnationRelationshipsRegionData {
                        id: result.region_id,
                    }),
                }),
            }),
        };

        // Construct the Region object
        let region = models::Region {
            id: result.region_id,
            attributes: Some(models::RegionAttributes {
                name: result.region_name.clone(),
                description: result.region_description.clone(),
            }),
            relationships: Some(models::RegionRelationships {
                parent: Some(models::GameRelationshipsWinnerAnswer {
                    data: result.parent_region_id.map(|id| swagger::Nullable::Present(models::GameRelationshipsWinnerAnswerData { id: Some(id) })),
                }),
            }),
        };

        // Construct the Parent Region object if it exists
        let parent_region = result.parent_region_id.map(|id| models::Region {
            id: Some(id),
            attributes: Some(models::RegionAttributes {
                name: result.parent_region_name.clone(),
                description: result.parent_region_description.clone(),
            }),
            relationships: Some(models::RegionRelationships {
                parent: Some(models::GameRelationshipsWinnerAnswer { data: None }),
            }),
        });

        // Construct the included data
        let mut included = vec![
            models::GamesIdGet200ResponseIncludedInner {
                id: incarnation.id,
                attributes: Some(models::AnswerAttributes {
                    answer: incarnation.attributes.as_ref().and_then(|attr| attr.answer.clone()),
                    correct: None, // You might want to set this based on your logic
                }),
                relationships: Some(models::AnswerRelationships {
                    game: None, // You might want to set this based on your logic
                }),
            },
            models::GamesIdGet200ResponseIncludedInner {
                id: region.id,
                attributes: Some(models::AnswerAttributes {
                    answer: Some(region.attributes.as_ref().map_or_else(String::new, |attr| attr.name.clone().unwrap_or_default())),
                    correct: None,
                }),
                relationships: Some(models::AnswerRelationships {
                    game: None,
                }),
            },
        ];

        // Add parent region to included if it exists
        if let Some(parent) = parent_region {
            included.push(models::GamesIdGet200ResponseIncludedInner {
                id: parent.id,
                attributes: Some(models::AnswerAttributes {
                    answer: Some(parent.attributes.as_ref().map_or_else(String::new, |attr| attr.name.clone().unwrap_or_default())),
                    correct: None,
                }),
                relationships: Some(models::AnswerRelationships {
                    game: None,
                }),
            });
        }

        // Construct the response
        let response = models::GamesIdGet200Response {
            data: Some(game),
            included: Some(included),
        };

        Ok(GamesIdGetResponse::SuccessfullyFetchedGame(response))
    }

    /// Create a new game
    async fn games_post(
        &self,
        game_input: models::GameInput,
        concept: Option<String>,
        incarnation_filter_left_square_bracket_concept_right_square_bracket: Option<String>,
        context: &C) -> Result<GamesPostResponse, ApiError>
    {
        info!("games_post({:?}, {:?}, {:?}) - X-Span-ID: {:?}", game_input, concept, incarnation_filter_left_square_bracket_concept_right_square_bracket, context.get().0.clone());
        Err(ApiError("Api-Error: Operation is NOT implemented".into()))
    }

}
