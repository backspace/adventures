pub mod helpers {
    use base64::{engine::general_purpose, Engine as _};
    use sqlx::PgPool;
    use std::env;
    use tokio::net::TcpListener;
    use unmnemonic_devices_vrs::config::{ConfigProvider, EnvVarProvider};
    use unmnemonic_devices_vrs::{app, InjectableServices};
    use wiremock::matchers::any;
    use wiremock::{Mock, MockServer, ResponseTemplate};

    pub struct TestApp {
        pub address: String,
    }

    pub async fn spawn_app(services: InjectableServices) -> TestApp {
        let listener = TcpListener::bind("127.0.0.1:0")
            .await
            .expect("Failed to bind random port");
        let port = listener.local_addr().unwrap().port();
        let address = format!("http://127.0.0.1:{}", port);

        tokio::spawn(async move {
            axum::serve(listener, app(services).await.into_make_service())
                .await
                .unwrap();
        });

        TestApp { address }
    }

    pub fn get_config() -> unmnemonic_devices_vrs::config::Config {
        let env_config_provider = EnvVarProvider::new(env::vars().collect());
        env_config_provider.get_config().clone()
    }

    pub async fn get(
        db: PgPool,
        path: &str,
        skip_redirects: bool,
    ) -> Result<reqwest::Response, reqwest::Error> {
        let mock_twilio = MockServer::start().await;

        Mock::given(any())
            .respond_with(ResponseTemplate::new(500))
            .expect(0)
            .named("Mock Twilio API")
            .mount(&mock_twilio)
            .await;

        get_with_twilio(
            InjectableServices {
                db,
                twilio_address: mock_twilio.uri(),
            },
            path,
            skip_redirects,
        )
        .await
    }

    pub async fn get_with_twilio(
        services: InjectableServices,
        path: &str,
        skip_redirects: bool,
    ) -> Result<reqwest::Response, reqwest::Error> {
        let env_config_provider = EnvVarProvider::new(env::vars().collect());
        let config = &env_config_provider.get_config();

        get_with_twilio_and_auth(services, path, skip_redirects, config.auth.clone()).await
    }

    pub async fn get_with_twilio_and_auth(
        services: InjectableServices,
        path: &str,
        skip_redirects: bool,
        auth: String,
    ) -> Result<reqwest::Response, reqwest::Error> {
        let app_address = spawn_app(services).await.address;
        let client_builder = reqwest::Client::builder();

        let client = if skip_redirects {
            client_builder
                .redirect(reqwest::redirect::Policy::none())
                .build()?
        } else {
            client_builder.build()?
        };

        client
            .get(&format!("{}{}", app_address, path))
            .header(
                "Authorization",
                format!("Basic {}", general_purpose::STANDARD.encode(auth)),
            )
            .send()
            .await
    }

    pub async fn post(
        db: PgPool,
        path: &str,
        body: &str,
        skip_redirects: bool,
    ) -> Result<reqwest::Response, reqwest::Error> {
        let mock_twilio = MockServer::start().await;

        Mock::given(any())
            .respond_with(ResponseTemplate::new(500))
            .expect(0)
            .named("Mock Twilio API")
            .mount(&mock_twilio)
            .await;

        post_with_twilio(
            InjectableServices {
                db,
                twilio_address: mock_twilio.uri(),
            },
            path,
            body,
            skip_redirects,
        )
        .await
    }

    pub async fn post_with_twilio(
        services: InjectableServices,
        path: &str,
        body: &str,
        skip_redirects: bool,
    ) -> Result<reqwest::Response, reqwest::Error> {
        let env_config_provider = EnvVarProvider::new(env::vars().collect());
        let config = &env_config_provider.get_config();
        let app_address = spawn_app(services).await.address;
        let client_builder = reqwest::Client::builder();

        let client = if skip_redirects {
            client_builder
                .redirect(reqwest::redirect::Policy::none())
                .build()?
        } else {
            client_builder.build()?
        };

        client
            .post(&format!("{}{}", app_address, path))
            .header(
                "Authorization",
                format!(
                    "Basic {}",
                    general_purpose::STANDARD.encode(config.auth.clone())
                ),
            )
            .header("Content-Type", "application/x-www-form-urlencoded")
            .body(body.to_string())
            .send()
            .await
    }

    pub trait RedirectTo {
        fn redirects_to(&mut self, expected_location: &str);
    }

    impl<'s> RedirectTo for speculoos::Spec<'s, reqwest::Response> {
        fn redirects_to(&mut self, expected_location: &str) {
            let response = self.subject;

            if !response.status().is_redirection() {
                speculoos::AssertionFailure::from_spec(self)
                    .with_expected("redirection status".to_string())
                    .with_actual(format!("{:?}", response.status()))
                    .fail();
                return;
            }

            let location = response
                .headers()
                .get("Location")
                .expect("Failed to extract Location header")
                .to_str()
                .expect("Failed to convert Location header to string");

            if location != expected_location {
                speculoos::AssertionFailure::from_spec(self)
                    .with_expected(format!("redirect to <{}>", expected_location))
                    .with_actual(format!("redirect to <{}>", location))
                    .fail();
            }
        }
    }
}
