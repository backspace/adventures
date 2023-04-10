use axum::{
    body::{Bytes, Full},
    extract::{Path, State},
    response::{IntoResponse, Response},
};
use axum_template::{Key, TemplateEngine};
use http::{header, HeaderValue};
use serde::Serialize;

use crate::AppState;

#[derive(Clone, Copy, Debug)]
#[must_use]
pub struct Xml<T>(pub T);

impl<T> IntoResponse for Xml<T>
where
    T: Into<Full<Bytes>>,
{
    fn into_response(self) -> Response {
        (
            [(
                header::CONTENT_TYPE,
                HeaderValue::from_static(mime::TEXT_XML.as_ref()),
            )],
            self.0.into(),
        )
            .into_response()
    }
}

impl<T> From<T> for Xml<T> {
    fn from(inner: T) -> Self {
        Self(inner)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RenderXml<K, E, S>(pub K, pub E, pub S);

impl<K, E, S> IntoResponse for RenderXml<K, E, S>
where
    E: TemplateEngine,
    S: Serialize,
    K: AsRef<str>,
{
    fn into_response(self) -> axum::response::Response {
        let RenderXml(key, engine, data) = self;

        let result = engine.render(key.as_ref(), data);

        match result {
            Ok(x) => Xml(x).into_response(),
            Err(x) => x.into_response(),
        }
    }
}
#[derive(Serialize)]
pub struct Team {
    name: String,
}

pub async fn get_team(
    Key(key): Key,
    Path(id): Path<i32>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let row: (String,) = sqlx::query_as("SELECT name FROM teams WHERE id = $1")
        .bind(id)
        .fetch_one(&state.db)
        .await
        .expect("Failed to fetch team");

    RenderXml(key, state.engine, Team { name: row.0 })
}
