use axum::{
    body::{Bytes, Full},
    response::{IntoResponse, Response},
};
use axum_template::TemplateEngine;
use http::{header, HeaderValue};
use serde::Serialize;

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

        // handlebars stores template paths with no leading slash but axum-template keys have one
        let mut adapted_key = String::from(key.as_ref());
        adapted_key.remove(0);

        // templates/.hbs doesn’t result in a key match
        if adapted_key.is_empty() {
            adapted_key = "root".to_string();
        }

        let result = engine.render(adapted_key.as_ref(), data);

        match result {
            Ok(x) => Xml(x).into_response(),
            Err(x) => x.into_response(),
        }
    }
}
