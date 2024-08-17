use axum::{
    routing::get,
};
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::signal;
use waydowntown_server::server;

struct ServerImpl;

#[async_trait::async_trait]
impl waydowntown_server::apis::default::Default for ServerImpl {
    async fn answers_post(
        &self,
        method: axum::http::Method,
        host: axum::extract::Host,
        cookies: axum_extra::extract::CookieJar,
        body: waydowntown_server::models::AnswerInput,
    ) -> Result<waydowntown_server::apis::default::AnswersPostResponse, String> {
        // Implementation
        todo!()
    }

    async fn games_id_get(
        &self,
        method: axum::http::Method,
        host: axum::extract::Host,
        cookies: axum_extra::extract::CookieJar,
        path_params: waydowntown_server::models::GamesIdGetPathParams,
    ) -> Result<waydowntown_server::apis::default::GamesIdGetResponse, String> {
        // Implementation
        todo!()
    }

    async fn games_post(
        &self,
        method: axum::http::Method,
        host: axum::extract::Host,
        cookies: axum_extra::extract::CookieJar,
        query_params: waydowntown_server::models::GamesPostQueryParams,
        body: waydowntown_server::models::GameInput,
    ) -> Result<waydowntown_server::apis::default::GamesPostResponse, String> {
        // Implementation
        todo!()
    }
}

#[tokio::main]
async fn main() {
    // Initialize tracing
    tracing_subscriber::fmt::init();

    // Create ServerImpl
    let server_impl = Arc::new(ServerImpl);

    let app = server::new(server_impl);


    // Run the server
    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    println!("Listening on {}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();

    axum::serve(listener, app)
        .with_graceful_shutdown(shutdown_signal())
        .await
        .unwrap();
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
