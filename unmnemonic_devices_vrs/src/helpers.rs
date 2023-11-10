use crate::Prompts;
use crate::WrappedPrompts;
use crate::WrappedPromptsSerialisation;
use serde::Deserialize;
use sqlx::PgPool;
use sqlx::Row;
use std::collections::HashMap;

pub async fn get_all_prompts(db: &PgPool, prompts: &Prompts) -> String {
    let query = r#"
    SELECT character_name, prompt_name, url
    FROM unmnemonic_devices.recordings
    WHERE
      url IS NOT NULL
      AND
      type IS NULL
      AND
      region_id IS NULL
    "#;

    let rows = sqlx::query(query).fetch_all(db).await.unwrap();

    let mut results = HashMap::new();
    for row in rows {
        let character_name: String = row.get("character_name");
        let prompt_name: String = row.get("prompt_name");
        let url: String = row.get("url");

        let key = format!("{}.{}", character_name, prompt_name);
        let prompt_text = prompts
            .tables
            .get(&character_name)
            .unwrap()
            .get(&prompt_name);
        let value = format!("<!-- {:?} --><Play>{}</Play>", prompt_text, url);
        results.insert(key, value);
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
