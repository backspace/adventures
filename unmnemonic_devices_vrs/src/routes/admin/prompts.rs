use axum::{
    extract::{Path, State},
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::{Key, RenderHtml};
use serde::{Deserialize, Serialize};
use sqlx::Row;
use std::collections::HashMap;
use uuid::Uuid;

use crate::auth::User;
use crate::helpers::get_all_prompts;
use crate::AppState;

#[derive(Serialize)]
pub struct Prompts {
    prompts: HashMap<String, HashMap<String, (String, Option<String>)>>,
}

#[axum_macros::debug_handler]
pub async fn get_admin_prompts(
    Key(key): Key,
    State(state): State<AppState>,
    _user: User,
) -> impl IntoResponse {
    let query = r#"
      SELECT character_name, prompt_name, url
      FROM unmnemonic_devices.recordings
      WHERE
        character_name IS NOT NULL AND
        prompt_name IS NOT NULL AND
        url IS NOT NULL AND
        type IS NULL AND
        region_id IS NULL AND
        destination_id IS NULL AND
        book_id IS NULL AND
        team_id IS NULL
      "#;

    let rows = sqlx::query(query).fetch_all(&state.db).await.unwrap();

    let mut namespaced_prompt_to_url = HashMap::new();
    for row in rows {
        let character_name: String = row.get("character_name");
        let prompt_name: String = row.get("prompt_name");
        let url: String = row.get("url");

        let key = format!("{}.{}", character_name, prompt_name);
        let value = url;
        namespaced_prompt_to_url.insert(key, value);
    }

    let mut character_prompts_with_urls: HashMap<
        String,
        HashMap<String, (String, Option<String>)>,
    > = HashMap::new();

    for (character, prompts) in state.prompts.tables.iter() {
        if !character.starts_with("test") {
            let mut character_name_to_prompt_and_maybe_url: HashMap<
                String,
                (String, Option<String>),
            > = HashMap::new();

            for (prompt_name, prompt_string) in prompts.clone().iter() {
                let key = format!("{}.{}", character, prompt_name);
                let url = namespaced_prompt_to_url.get(&key).cloned();
                character_name_to_prompt_and_maybe_url
                    .insert(prompt_name.clone(), (prompt_string.clone(), url));
            }

            character_prompts_with_urls
                .insert(character.clone(), character_name_to_prompt_and_maybe_url);
        }
    }

    RenderHtml(
        key.chars().skip(1).collect::<String>(),
        state.engine,
        Prompts {
            prompts: character_prompts_with_urls,
        },
    )
}

#[derive(Deserialize)]
pub struct PromptForm {
    url: String,
}

#[axum_macros::debug_handler]
pub async fn post_admin_prompt(
    Key(_key): Key,
    Path((character_name, prompt_name)): Path<(String, String)>,
    State(state): State<AppState>,
    _user: User,
    Form(form): Form<PromptForm>,
) -> Redirect {
    sqlx::query!(
        r#"
          INSERT INTO unmnemonic_devices.recordings (id, character_name, prompt_name, url)
          VALUES ($1, $2, $3, $4)
          ON CONFLICT (character_name, prompt_name)
          DO UPDATE SET url = EXCLUDED.url, call_id = EXCLUDED.call_id
        "#,
        Uuid::new_v4(),
        character_name,
        prompt_name,
        form.url,
    )
    .execute(&state.db)
    .await
    .ok();

    // Update wrapped prompts in AppState
    let new_wrapped_prompts = get_all_prompts(&state.db, &state.prompts).await;
    *state.mutable_prompts.lock().unwrap() = new_wrapped_prompts;

    Redirect::to("/admin/prompts")
}
