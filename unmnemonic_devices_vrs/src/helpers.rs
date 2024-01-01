use crate::AppState;
use crate::Prompts;
use crate::WrappedPrompts;
use crate::WrappedPromptsSerialisation;
use axum::response::Response;
use axum::{extract::State, http::StatusCode, middleware::Next};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use sqlx::Row;
use std::collections::HashMap;

pub async fn get_all_prompts(db: &PgPool, prompts: &Prompts) -> String {
    let query = r#"
    SELECT character_name, prompt_name, url
    FROM unmnemonic_devices.recordings
    WHERE
      character_name IS NOT NULL AND
      prompt_name IS NOT NULL AND
      url IS NOT NULL
    "#;

    let rows = sqlx::query(query).fetch_all(db).await.unwrap();

    let mut results = HashMap::new();
    for row in rows {
        let character_name: String = row.get("character_name");
        let prompt_name: String = row.get("prompt_name");
        let url: String = row.get("url");

        let key = format!("{}.{}", character_name, prompt_name);

        let is_prompt = prompts.tables.contains_key(&character_name)
            && prompts
                .tables
                .get(&character_name)
                .unwrap()
                .contains_key(&prompt_name);

        if is_prompt {
            let prompt_text = prompts
                .tables
                .get(&character_name)
                .unwrap()
                .get(&prompt_name);
            let value = format!("<!-- {:?} --><Play>{}</Play>", prompt_text, url);
            results.insert(key, value);
        }
    }

    for (character, prompts) in &prompts.tables {
        for (prompt_name, value) in prompts {
            let key = format!("{}.{}", character, prompt_name);

            results.entry(key).or_insert_with(|| {
                format!(
                    "<!-- {:?} --><Say>{:?}</Say>",
                    prompt_name,
                    value.to_string()
                )
            });
        }
    }

    (WrappedPrompts { prompts: results }).serialize_to_string()
}

#[derive(Deserialize)]
pub struct MaybeRecordingParams {
    pub unrecorded: Option<String>,
}

#[derive(Deserialize, Debug)]
#[serde(rename_all = "PascalCase")]
struct CallParams {
    call_sid: Option<String>,
}

pub async fn store_call_path_middleware<B>(
    State(state): State<AppState>,
    req: axum::http::Request<B>,
    next: Next<B>,
) -> Result<Response, StatusCode> {
    if req.method() == axum::http::Method::GET {
        if let Some(query) = req.uri().query() {
            if let Ok(call_params) = serde_urlencoded::from_str::<CallParams>(query) {
                if let Some(call_sid) = call_params.call_sid {
                    let db = &state.db;
                    let path = req.uri().path().to_string();

                    sqlx::query!(
                        "
                        UPDATE unmnemonic_devices.calls
                        SET path = $1 WHERE id = $2
                        ",
                        path,
                        call_sid
                    )
                    .execute(db)
                    .await
                    .ok();
                }
            }
        }
    }

    Ok(next.run(req).await)
}

#[derive(Serialize)]
pub struct ConfirmRecordingPrompt {
    pub recording_url: String,
    pub action: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "PascalCase")]
pub struct TwilioParams {
    pub call_sid: String,
}
