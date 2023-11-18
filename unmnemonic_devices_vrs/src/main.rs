use axum::Server;
use sqlx::PgPool;
use std::env;
use std::net::{SocketAddr, TcpListener};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use unmnemonic_devices_vrs::config::{ConfigProvider, EnvVarProvider};
use unmnemonic_devices_vrs::{app, InjectableServices};

#[tokio::main]
async fn main() {
    let env_config_provider = EnvVarProvider::new(env::vars().collect());
    let config = &env_config_provider.get_config();

    let database_url = &config.database_url;
    let db = PgPool::connect(database_url.as_str()).await.unwrap();

    let listener_address = "127.0.0.1:3000";
    let listener = TcpListener::bind(listener_address.parse::<SocketAddr>().unwrap()).unwrap();

    println!("unmnemonic devices VRS listening on {}", listener_address);

    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| {
                // axum logs rejections from built-in extractors with the `axum::rejection`
                // target, at `TRACE` level. `axum::rejection=trace` enables showing those events
                "example_tracing_aka_logging=debug,tower_http=debug,axum::rejection=trace".into()
            }),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    Server::from_tcp(listener)
        .expect("Failed to listen")
        .serve(
            app(InjectableServices {
                db,
                twilio_address: config.twilio_url.to_string(),
            })
            .await
            .into_make_service(),
        )
        .await
        .expect("Failed to start server")
}
