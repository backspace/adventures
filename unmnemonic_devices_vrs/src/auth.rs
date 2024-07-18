use crate::{
    config::{ConfigProvider, EnvVarProvider},
    AppState,
};
use axum::{
    async_trait,
    extract::{FromRef, FromRequestParts},
    http::{request::Parts, StatusCode},
};
use base64::{engine::general_purpose, Engine as _};
use pbkdf2::{
    password_hash::{PasswordHash, PasswordVerifier},
    Pbkdf2,
};
use serde::Serialize;
use std::{env, str::from_utf8};

// Adapted from https://www.shuttle.rs/blog/2023/09/27/rust-vs-go-comparison#middleware-1

// A user that is authorized to access admin routes.
pub struct User;

#[derive(sqlx::FromRow, Serialize, Debug)]
pub struct UserPasswordHash {
    password_hash: String,
}

#[async_trait]
impl<S> FromRequestParts<S> for User
where
    AppState: FromRef<S>,
    S: Send + Sync,
{
    type Rejection = axum::http::Response<axum::body::Body>;

    async fn from_request_parts(
        parts: &mut Parts,
        state_reference: &S,
    ) -> Result<Self, Self::Rejection> {
        let env_config_provider = EnvVarProvider::new(env::vars().collect());
        let config = &env_config_provider.get_config();

        let auth_header = parts
            .headers
            .get("Authorization")
            .and_then(|header| header.to_str().ok());

        if let Some(auth_header) = auth_header {
            if auth_header.starts_with("Basic ") {
                let credentials = auth_header.trim_start_matches("Basic ");
                let decoded = general_purpose::STANDARD
                    .decode(credentials)
                    .expect("Unable to decode credentials");
                let credential_str = from_utf8(&decoded).unwrap_or("");

                // Preserving ENV-set auth for now
                if credential_str == config.auth {
                    return Ok(User);
                } else {
                    let state = AppState::from_ref(state_reference);

                    let (username, password) = credential_str.split_once(':').unwrap_or(("", ""));

                    let maybe_user = sqlx::query_as::<_, UserPasswordHash>(
                        r#"
                        SELECT
                          password_hash
                        FROM
                          users
                        WHERE
                          email = $1 AND admin IS TRUE;
                      "#,
                    )
                    .bind(username)
                    .fetch_one(&state.db)
                    .await;

                    if let Ok(maybe_user) = maybe_user {
                        let user = UserPasswordHash {
                            password_hash: maybe_user.password_hash,
                        };

                        // Pow in Elixir is creating a string with slight differences that are failing to parse
                        let converted_user_password_hash = user
                            .password_hash
                            .replace("==", "")
                            .replace("$pbkdf2-sha512$100000", "$pbkdf2-sha512$i=100000,l=64");

                        let parsed_hash = PasswordHash::new(&converted_user_password_hash);

                        if Pbkdf2
                            .verify_password(password.as_bytes(), &parsed_hash.unwrap())
                            .is_ok()
                        {
                            return Ok(User);
                        }
                    }
                }
            }
        }

        let reject_response = axum::http::Response::builder()
            .status(StatusCode::UNAUTHORIZED)
            .header(
                "WWW-Authenticate",
                "Basic realm=\"Please enter your credentials\"",
            )
            .body(axum::body::Body::from("Unauthorized"))
            .unwrap();

        Err(reject_response)
    }
}
