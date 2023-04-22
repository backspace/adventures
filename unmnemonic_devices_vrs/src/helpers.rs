use crate::Prompts;
use sqlx::PgPool;
use sqlx::Row;
use std::collections::HashMap;

pub async fn get_prompts(
    character_and_prompts: &[&str],
    db: PgPool,
    prompts: Prompts,
) -> Result<HashMap<String, String>, String> {
    let (character_names, prompt_names): (Vec<&str>, Vec<&str>) = character_and_prompts
        .iter()
        .map(|s| s.split_once('.').unwrap())
        .unzip();

    let query = r#"
        SELECT character_name, prompt_name, url
        FROM unmnemonic_devices.recordings
        WHERE (character_name, prompt_name) IN (
            SELECT * FROM UNNEST($1::text[], $2::text[])
        ) AND url IS NOT NULL
        "#;

    let rows = sqlx::query(query)
        .bind(character_names)
        .bind(prompt_names)
        .fetch_all(&db)
        .await
        .unwrap();

    let mut results = HashMap::new();
    for row in rows {
        let character_name: String = row.get("character_name");
        let prompt_name: String = row.get("prompt_name");
        let url: String = row.get("url");

        let key = format!("{}.{}", character_name, prompt_name);
        let value = format!("<Play>{}</Play>", url);
        results.insert(key, value);
    }

    for character_and_prompt in character_and_prompts {
        let character_and_prompt = *character_and_prompt;
        if !results.contains_key(character_and_prompt) {
            let (character_name, prompt_name) = character_and_prompt.split_once(".").unwrap();
            let prompt_text = prompts.tables.get(character_name).unwrap().get(prompt_name);

            if let Some(prompt_text) = prompt_text {
                let value = format!("<Say>{}</Say>", prompt_text.to_string());
                results.insert(character_and_prompt.to_string(), value);
            } else {
                return Err(format!("Missing prompt: {}", character_and_prompt));
            }
        }
    }

    Ok(results)
}
