use axum::{
    extract::{Path, Query, State},
    response::{IntoResponse, Redirect},
    Form,
};
use axum_template::Key;
use serde::{Deserialize, Serialize};
use sqlx::{types::Uuid, PgPool};

use crate::{
    helpers::MaybeRecordingParams,
    render_xml::RenderXml,
    twilio_form::{TwilioForm, TwilioRecordingForm},
    AppState,
};

#[derive(Debug, Serialize)]
pub struct Regions {
    regions: Vec<Region>,
    add_unrecorded: bool,
}

#[derive(Debug, sqlx::FromRow, Serialize)]
pub struct Region {
    id: Uuid,
    synthetic_id: i64,
}

#[axum_macros::debug_handler]
pub async fn get_recording_regions(
    Key(key): Key,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let regions = sqlx::query_as::<_, Region>(
        r#"
        SELECT id, ROW_NUMBER() OVER (ORDER BY created_at ASC) AS synthetic_id
        FROM unmnemonic_devices.regions
        ORDER BY created_at
      "#,
    )
    .fetch_all(&state.db)
    .await
    .expect("Failed to fetch regions");

    let unrecorded_region = find_unrecorded_region(state.db).await;

    RenderXml(
        key,
        state.engine,
        state.mutable_prompts.lock().unwrap().to_string(),
        Regions {
            regions,
            add_unrecorded: unrecorded_region.is_ok() && unrecorded_region.unwrap().is_some(),
        },
    )
}

#[derive(Serialize)]
pub struct RegionNotFound {
    id: String,
}

#[axum_macros::debug_handler]
pub async fn post_recording_regions(
    State(state): State<AppState>,
    Form(form): Form<TwilioForm>,
) -> impl IntoResponse {
    if form.speech_result == "unrecorded" {
        Redirect::to("/recordings/regions/unrecorded").into_response()
    } else {
        let region_id = sqlx::query_as::<_, Region>(
            r#"
              WITH ordered_regions AS (
                SELECT
                  ROW_NUMBER() OVER (ORDER BY created_at ASC) AS synthetic_id,
                  id
                FROM
                  unmnemonic_devices.regions
              )
              SELECT id, synthetic_id
              FROM ordered_regions
              WHERE synthetic_id = CAST($1 AS BIGINT);
            "#,
        )
        .bind(form.speech_result.clone())
        .fetch_optional(&state.db)
        .await
        .expect("Failed to fetch regions");

        if region_id.is_some() {
            Redirect::to(&format!("/recordings/regions/{}", region_id.unwrap().id)).into_response()
        } else {
            RenderXml(
                "/recordings/regions/not-found",
                state.engine,
                state.mutable_prompts.lock().unwrap().to_string(),
                RegionNotFound {
                    id: form.speech_result,
                },
            )
            .into_response()
        }
    }
}

#[derive(Serialize)]
pub struct UnrecordedIntroduction {
    skip_message: bool,
    redirect: String,
}

#[axum_macros::debug_handler]
pub async fn get_unrecorded_region(
    State(state): State<AppState>,
    params: Query<MaybeRecordingParams>,
) -> impl IntoResponse {
    let unrecorded_region = find_unrecorded_region(state.db).await;

    if unrecorded_region.is_ok() && unrecorded_region.as_ref().unwrap().is_some() {
        RenderXml(
            "/recordings/regions/unrecorded",
            state.engine,
            state.mutable_prompts.lock().unwrap().to_string(),
            UnrecordedIntroduction {
                skip_message: params.unrecorded.is_some(),
                redirect: format!(
                    "/recordings/regions/{}?unrecorded",
                    unrecorded_region.as_ref().unwrap().as_ref().unwrap().id
                ),
            },
        )
        .into_response()
    } else {
        RenderXml(
            "/recordings/regions/no-unrecorded",
            state.engine,
            state.mutable_prompts.lock().unwrap().to_string(),
            UnrecordedIntroduction {
                skip_message: false,
                redirect: "/recordings/".to_string(),
            },
        )
        .into_response()
    }
}

#[derive(Serialize)]
pub struct GetRecording {
    region: Region,
    action: String,
}

#[axum_macros::debug_handler]
pub async fn get_recording_region(
    Key(key): Key,
    Path(id): Path<Uuid>,
    params: Query<MaybeRecordingParams>,
    State(state): State<AppState>,
) -> impl IntoResponse {
    let region = sqlx::query_as::<_, Region>(
        r#"
          WITH ordered_regions AS (
            SELECT
              ROW_NUMBER() OVER (ORDER BY created_at ASC) AS synthetic_id,
              id
            FROM
              unmnemonic_devices.regions
          )
          SELECT id, synthetic_id
          FROM ordered_regions
          WHERE id = $1;
        "#,
    )
    .bind(id)
    .fetch_one(&state.db)
    .await
    .expect("Failed to fetch region");

    let action = format!(
        "/recordings/regions/{}{}",
        region.id,
        if params.unrecorded.is_some() {
            "?unrecorded"
        } else {
            ""
        }
    );

    RenderXml(
        key,
        state.engine,
        state.mutable_prompts.lock().unwrap().to_string(),
        GetRecording { region, action },
    )
    .into_response()
}

#[derive(Serialize)]
pub struct ConfirmRecordingPrompt {
    recording_url: String,
    action: String,
}

#[axum_macros::debug_handler]
pub async fn post_recording_region(
    Path(id): Path<Uuid>,
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
                "/recordings/regions/{}/decide?recording_url={}{}",
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
pub async fn post_recording_region_decide(
    Key(_key): Key,
    Path(id): Path<Uuid>,
    params: Query<DecideParams>,
    State(state): State<AppState>,
    Form(form): Form<TwilioForm>,
) -> impl IntoResponse {
    if form.speech_result == "keep" {
        let result = sqlx::query!(
            r#"
              INSERT INTO unmnemonic_devices.recordings (id, region_id, url, call_id)
              VALUES ($1, $2, $3, $4)
              ON CONFLICT (region_id)
              DO UPDATE SET url = EXCLUDED.url, call_id = EXCLUDED.call_id
            "#,
            Uuid::new_v4(),
            id,
            params.recording_url,
            form.call_sid.unwrap()
        )
        .execute(&state.db)
        .await;

        if result.is_ok() {
            Redirect::to(&format!(
                "/recordings/regions{}",
                if params.unrecorded.is_some() {
                    "/unrecorded?unrecorded"
                } else {
                    ""
                }
            ))
        } else {
            // How to exercise this in tests?
            Redirect::to(&format!(
                "/recordings/regions/{}/{}",
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
            "/recordings/regions/{}{}",
            id,
            if params.unrecorded.is_some() {
                "?unrecorded"
            } else {
                ""
            }
        ))
    }
}

async fn find_unrecorded_region(db: PgPool) -> Result<Option<Region>, sqlx::Error> {
    sqlx::query_as::<_, Region>(
        r#"
      SELECT id, CAST(0 AS BIGINT) as synthetic_id
      FROM unmnemonic_devices.regions
      WHERE
        id NOT IN (
          SELECT region_id
          FROM unmnemonic_devices.recordings
          WHERE region_id IS NOT NULL
        )
      ORDER BY created_at
      LIMIT 1
    "#,
    )
    .fetch_optional(&db)
    .await
}
