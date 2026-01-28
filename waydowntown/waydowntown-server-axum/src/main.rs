use std::net::SocketAddr;
use std::sync::Arc;
use tokio::signal;
use waydowntown_server::server;
use waydowntown_server::models;
use waydowntown_server::apis::default::{self, Default as WaydowntownDefault};
use sqlx::postgres::PgPoolOptions;
use sqlx::PgPool;

struct ServerImpl {
    db: PgPool,
}

#[async_trait::async_trait]
impl WaydowntownDefault for ServerImpl {
    async fn answers_post(
        &self,
        method: axum::http::Method,
        host: axum::extract::Host,
        cookies: axum_extra::extract::CookieJar,
        body: models::AnswerInput,
    ) -> Result<default::AnswersPostResponse, String> {
        let answer = sqlx::query_as!(
            models::Answer,
            r#"
            INSERT INTO waydowntown.answers (game_id, answer)
            VALUES ($1, $2)
            RETURNING id, answer, correct
            "#,
            body.game.data.id,
            body.answer
        )
        .fetch_one(&self.db)
        .await
        .map_err(|e| e.to_string())?;

        Ok(default::AnswersPostResponse::Status201_SuccessfullyCreatedAnswer(answer))
    }

    async fn games_id_get(
        &self,
        method: axum::http::Method,
        host: axum::extract::Host,
        cookies: axum_extra::extract::CookieJar,
        path_params: models::GamesIdGetPathParams,
    ) -> Result<default::GamesIdGetResponse, String> {
        let game = sqlx::query_as!(
            models::Game,
            r#"
            SELECT id, CASE WHEN winner_answer_id IS NOT NULL THEN true ELSE false END as complete
            FROM waydowntown.games
            WHERE id = $1
            "#,
            path_params.id
        )
        .fetch_one(&self.db)
        .await
        .map_err(|e| e.to_string())?;

        Ok(default::GamesIdGetResponse::Status200_SuccessfullyFetchedGame(
            models::GamesIdGet200Response {
                data: game,
                included: vec![],
            }
        ))
    }

    async fn games_post(
        &self,
        method: axum::http::Method,
        host: axum::extract::Host,
        cookies: axum_extra::extract::CookieJar,
        query_params: models::GamesPostQueryParams,
        body: models::GameInput,
    ) -> Result<default::GamesPostResponse, String> {
        let game = sqlx::query_as!(
            models::Game,
            r#"
            INSERT INTO waydowntown.games (incarnation_id)
            VALUES ($1)
            RETURNING id, CASE WHEN winner_answer_id IS NOT NULL THEN true ELSE false END as complete
            "#,
            body.incarnation_id
        )
        .fetch_one(&self.db)
        .await
        .map_err(|e| e.to_string())?;

        Ok(default::GamesPostResponse::Status201_SuccessfullyCreatedGame(
            models::GamesPost201Response {
                data: game,
                included: vec![],
            }
        ))
    }
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize tracing
    tracing_subscriber::fmt::init();

    // Set up database connection
    let database_url = "postgres://postgres:postgres@localhost/registrations_dev";
    let db_pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(database_url)
        .await?;

    // Create ServerImpl
    let server_impl = Arc::new(ServerImpl { db: db_pool });

    let app = server::new(server_impl);

    // Run the server
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    println!("Listening on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await?;

    Ok(())
}

async fn shutdown_signal() {
    let ctrl_c = async {
        signal::ctrl_c()
            .await
            .expect("failed to install Ctrl+C handler");
    };

    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("failed to install signal handler")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => {},
        _ = terminate => {},
    }

    println!("Shutdown signal received, starting graceful shutdown");
}
