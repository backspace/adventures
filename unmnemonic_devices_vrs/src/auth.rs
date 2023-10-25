use axum::{
    async_trait,
    extract::FromRequestParts,
    http::{request::Parts, StatusCode},
};
use base64::{engine::general_purpose, Engine as _};
use std::str::from_utf8;

// Adapted from https://www.shuttle.rs/blog/2023/09/27/rust-vs-go-comparison#middleware-1

// A user that is authorized to access the stats endpoint.
//
// No fields are required, we just need to know that the user is authorized. In
// a production application you would probably want to have some kind of user
// ID or similar here.
pub struct User;

#[async_trait]
impl<S> FromRequestParts<S> for User
where
    S: Send + Sync,
{
    type Rejection = axum::http::Response<axum::body::Body>;

    async fn from_request_parts(parts: &mut Parts, _: &S) -> Result<Self, Self::Rejection> {
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

                // Our username and password are hardcoded here.
                // In a real app, you'd want to read them from the environment.
                if credential_str == "f:x" {
                    return Ok(User);
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
