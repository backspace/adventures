use axum::Server;
use std::net::TcpListener;
use unmnemonic_devices_vrs::app;

#[tokio::test]
async fn root_works() {
    let listener = TcpListener::bind("127.0.0.1:0").expect("Failed to bind random port");
    let port = listener.local_addr().unwrap().port();
    let address = format!("http://127.0.0.1:{}", port);

    let server = Server::from_tcp(listener)
        .expect("Failed to listen")
        .serve(app().into_make_service());
    let _ = tokio::spawn(server);

    let client = reqwest::Client::new();

    let response = client
        .get(&format!("{}/", &address))
        .send()
        .await
        .expect("Failed to execute request.");

    assert!(response.status().is_success());
    assert!(response.text().await.unwrap().contains("unmnemonic"));
}
