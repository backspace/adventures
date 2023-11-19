use axum::{
    extract::{Path, Query, State},
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;
use serde::{Deserialize, Serialize};
use sqlx::{types::Uuid, PgPool, Row};

use crate::{
    helpers::MaybeRecordingParams,
    render_xml::RenderXml,
    twilio_form::{TwilioForm, TwilioRecordingForm},
    AppState,
};

fn schema_for_object(object: &str) -> &'static str {
    if object == "teams" {
        "public"
    } else {
        "unmnemonic_devices"
    }
}

#[derive(Debug, Serialize)]
pub struct Objects {
    objects: Vec<ObjectIdentifiers>,
    singular_type: String,
    add_unrecorded: bool,
}

#[derive(Debug, sqlx::FromRow, Serialize)]
pub struct ObjectIdentifiers {
    id: Uuid,
    synthetic_id: i64,
}

#[axum_macros::debug_handler]
pub async fn get_recording_objects(
    Key(key): Key,
    Path(object): Path<String>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let objects = sqlx::query_as::<_, ObjectIdentifiers>(&format!(
        r#"
          SELECT id, ROW_NUMBER() OVER (ORDER BY inserted_at ASC) AS synthetic_id
          FROM {}.{}
          ORDER BY inserted_at
        "#,
        schema_for_object(&object),
        object.clone(),
    ))
    .fetch_all(&state.db)
    .await
    .expect("Failed to fetch objects");

    let unrecorded_region = find_unrecorded_object(state.db, object.clone()).await;

    let mut singular = object.clone();
    singular.pop();

    RenderXml(
        key,
        state.engine,
        state.mutable_prompts.lock().unwrap().to_string(),
        Objects {
            objects,
            singular_type: singular,
            add_unrecorded: unrecorded_region.is_some(),
        },
    )
}

#[derive(Serialize)]
pub struct ObjectNotFound {
    id: String,
    object_type: String,
    singular_type: String,
}

#[axum_macros::debug_handler]
pub async fn post_recording_objects(
    Path(object): Path<String>,
    State(state): State<AppState>,
    Form(form): Form<TwilioForm>,
) -> impl IntoResponse {
    if form.speech_result == "unrecorded" {
        Redirect::to(&format!("/recordings/{}/unrecorded", object.clone())).into_response()
    } else {
        let object_id = sqlx::query_as::<_, ObjectIdentifiers>(&format!(
            r#"
              WITH ordered_objects AS (
                SELECT
                  ROW_NUMBER() OVER (ORDER BY inserted_at ASC) AS synthetic_id,
                  id
                FROM
                  {}.{}
              )
              SELECT id, synthetic_id
              FROM ordered_objects
              WHERE synthetic_id = CAST($1 AS BIGINT);
            "#,
            schema_for_object(&object),
            object.clone(),
        ))
        .bind(form.speech_result.clone())
        .fetch_optional(&state.db)
        .await
        .expect("Failed to fetch regions");

        if object_id.is_some() {
            Redirect::to(&format!("/recordings/{}/{}", object, object_id.unwrap().id))
                .into_response()
        } else {
            let mut singular = object.clone();
            singular.pop();

            RenderXml(
                "/recordings/:object/not-found",
                state.engine,
                state.mutable_prompts.lock().unwrap().to_string(),
                ObjectNotFound {
                    id: form.speech_result,
                    object_type: object,
                    singular_type: singular,
                },
            )
            .into_response()
        }
    }
}

#[derive(Serialize)]
pub struct UnrecordedIntroduction {
    object_type: String,
    skip_message: bool,
    redirect: String,
}

#[axum_macros::debug_handler]
pub async fn get_unrecorded_object(
    State(state): State<AppState>,
    Path(object): Path<String>,
    params: Query<MaybeRecordingParams>,
) -> impl IntoResponse {
    let unrecorded_region = find_unrecorded_object(state.db, object.clone()).await;

    if unrecorded_region.is_some() {
        RenderXml(
            "/recordings/:object/unrecorded",
            state.engine,
            state.mutable_prompts.lock().unwrap().to_string(),
            UnrecordedIntroduction {
                object_type: object.clone(),
                skip_message: params.unrecorded.is_some(),
                redirect: format!(
                    "/recordings/{}/{}?unrecorded",
                    object,
                    unrecorded_region.as_ref().unwrap().id
                ),
            },
        )
        .into_response()
    } else {
        RenderXml(
            "/recordings/:object/no-unrecorded",
            state.engine,
            state.mutable_prompts.lock().unwrap().to_string(),
            UnrecordedIntroduction {
                object_type: object,
                skip_message: false,
                redirect: "/recordings/".to_string(),
            },
        )
        .into_response()
    }
}

#[derive(Serialize)]
pub struct GetRecording {
    singular_type: String,
    object: ObjectIdentifiers,
    action: String,
}

#[axum_macros::debug_handler]
pub async fn get_recording_object(
    Key(key): Key,
    Path((object, id)): Path<(String, Uuid)>,
    params: Query<MaybeRecordingParams>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let row = sqlx::query(&format!(
        r#"
          WITH ordered_objects AS (
            SELECT
              ROW_NUMBER() OVER (ORDER BY inserted_at ASC) AS synthetic_id,
              id
            FROM
              {}.{}
          )
          SELECT id, synthetic_id
          FROM ordered_objects
          WHERE id = $1;
        "#,
        schema_for_object(&object),
        object
    ))
    .bind(id)
    .fetch_one(&state.db)
    .await
    .expect("Failed to fetch object");

    let action = format!(
        "/recordings/{}/{}{}",
        object,
        row.get::<Uuid, &str>("id"),
        if params.unrecorded.is_some() {
            "?unrecorded"
        } else {
            ""
        }
    );

    let mut singular = object.clone();
    singular.pop();

    RenderXml(
        key,
        state.engine,
        state.mutable_prompts.lock().unwrap().to_string(),
        GetRecording {
            singular_type: singular,
            object: ObjectIdentifiers {
                id: row.get("id"),
                synthetic_id: row.get("synthetic_id"),
            },
            action,
        },
    )
    .into_response()
}

#[derive(Serialize)]
pub struct ConfirmRecordingPrompt {
    recording_url: String,
    action: String,
}

#[axum_macros::debug_handler]
pub async fn post_recording_object(
    Path((object, id)): Path<(String, Uuid)>,
    State(state): State<AppState>,
    params: Query<MaybeRecordingParams>,
    Form(form): Form<TwilioRecordingForm>,
) -> impl IntoResponse {
    RenderXml(
        "/recordings/prompts/:character_name/:prompt_name/post",
        state.engine,
        state.mutable_prompts.lock().unwrap().to_string(),
        ConfirmRecordingPrompt {
            recording_url: form.recording_url.to_string(),
            action: format!(
                "/recordings/{}/{}/decide?recording_url={}{}",
                object,
                id,
                urlencoding::encode(&form.recording_url),
                if params.unrecorded.is_some() {
                    "&unrecorded"
                } else {
                    ""
                }
            ),
        },
    )
}

#[derive(Deserialize)]
pub struct DecideParams {
    recording_url: String,
    unrecorded: Option<String>,
}

#[axum_macros::debug_handler]
pub async fn post_recording_object_decide(
    Key(_key): Key,
    Path((object, id)): Path<(String, Uuid)>,
    params: Query<DecideParams>,
    State(state): State<AppState>,
    Form(form): Form<TwilioForm>,
) -> impl IntoResponse {
    let mut singular = object.clone();
    singular.pop();

    let id_field = format!("{}_id", singular);

    if form.speech_result == "keep" {
        let result = sqlx::query(&format!(
            r#"
              INSERT INTO unmnemonic_devices.recordings (id, {}, url, call_id)
              VALUES ($1, $2, $3, $4)
              ON CONFLICT ({})
              DO UPDATE SET url = EXCLUDED.url, call_id = EXCLUDED.call_id
            "#,
            id_field, id_field
        ))
        .bind(Uuid::new_v4())
        .bind(id)
        .bind(params.recording_url.clone())
        .bind(form.call_sid.unwrap())
        .execute(&state.db)
        .await;

        println!("result?? {:?}", result);

        if result.is_ok() {
            Redirect::to(&format!(
                "/recordings/{}{}",
                object,
                if params.unrecorded.is_some() {
                    "/unrecorded?unrecorded"
                } else {
                    ""
                }
            ))
        } else {
            // How to exercise this in tests?
            Redirect::to(&format!(
                "/recordings/{}/{}/{}",
                object,
                id,
                if params.unrecorded.is_some() {
                    "?unrecorded"
                } else {
                    ""
                }
            ))
        }
    } else {
        Redirect::to(&format!(
            "/recordings/{}/{}{}",
            object,
            id,
            if params.unrecorded.is_some() {
                "?unrecorded"
            } else {
                ""
            }
        ))
    }
}

async fn find_unrecorded_object(db: PgPool, object: String) -> Option<ObjectIdentifiers> {
    let mut singular = object.clone();
    singular.pop();

    let id: String = format!("{}_id", singular);

    let result = sqlx::query(&format!(
        r#"
          SELECT id, CAST(0 AS BIGINT) as synthetic_id
          FROM {}.{}
          WHERE
            id NOT IN (
              SELECT {}
              FROM unmnemonic_devices.recordings
              WHERE {} IS NOT NULL
            )
          ORDER BY inserted_at
          LIMIT 1
        "#,
        schema_for_object(&object),
        object,
        id,
        id,
    ))
    .fetch_optional(&db)
    .await;

    if result.is_ok() && result.as_ref().unwrap().is_some() {
        let row = result.unwrap().unwrap();
        Some(ObjectIdentifiers {
            id: row.get("id"),
            synthetic_id: row.get("synthetic_id"),
        })
    } else {
        None
    }
}
