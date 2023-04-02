use axum::Server;
use sqlx::PgPool;
use std::env;
use std::net::{SocketAddr, TcpListener};
use unmnemonic_devices_vrs::app;

#[tokio::main]
async fn main() {
    let database_url = env::var("DATABASE_URL").expect("DATABASE_URL is not set in .env file");
    let db = PgPool::connect(&database_url).await.unwrap();

    let listener_address = "127.0.0.1:3000";
    let listener = TcpListener::bind(listener_address.parse::<SocketAddr>().unwrap()).unwrap();

    println!("unmnemonic devices VRS listening on {}", listener_address);

    Server::from_tcp(listener)
        .expect("Failed to listen")
        .serve(app(db).await.into_make_service())
        .await
        .expect("Failed to start server")
}
