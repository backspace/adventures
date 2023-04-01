use axum::Server;
use std::net::{SocketAddr, TcpListener};
use unmnemonic_devices_vrs::app;

#[tokio::main]
async fn main() {
    let listener = TcpListener::bind("127.0.0.1:3000".parse::<SocketAddr>().unwrap()).unwrap();
    Server::from_tcp(listener)
        .expect("Failed to listen")
        .serve(app().into_make_service());
}
