use axum::Server;
use sqlx::PgPool;
use std::net::TcpListener;
use unmnemonic_devices_vrs::app;

pub struct TestApp {
    pub address: String,
}

pub async fn spawn_app(db: PgPool) -> TestApp {
    let listener = TcpListener::bind("127.0.0.1:0").expect("Failed to bind random port");
    let port = listener.local_addr().unwrap().port();
    let address = format!("http://127.0.0.1:{}", port);

    let server = Server::from_tcp(listener)
        .expect("Failed to listen")
        .serve(app(db).await.into_make_service());
    let _ = tokio::spawn(server);

    TestApp { address }
}
