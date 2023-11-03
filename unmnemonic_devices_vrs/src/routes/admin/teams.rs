use axum::{extract::State, response::IntoResponse};
use axum_template::{Key, RenderHtml};
use serde::Serialize;

use crate::auth::User;
use crate::AppState;

#[derive(Serialize)]
pub struct Teams {
    teams: Vec<Team>,
}

#[derive(sqlx::FromRow, Serialize)]
pub struct Team {
    name: String,
    voicepass: String,
    region_listens: Vec<String>,
    complete: bool,
}

#[axum_macros::debug_handler]
pub async fn get_admin_teams(
    Key(key): Key,
    State(state): State<AppState>,
    _user: User,
) -> impl IntoResponse {
    let teams = sqlx::query_as::<_, Team>(
        r#"
            SELECT
                t.name AS name,
                t.voicepass AS voicepass,
                complete,
                ARRAY_AGG(region_listens ORDER BY region_listens) AS region_listens
            FROM (
                SELECT
                    t.name,
                    t.listens > 0 as complete,
                    t.voicepass,
                    r.name || ': ' || COALESCE(SUM(m.listens), 0) AS region_listens
                FROM
                    teams t
                LEFT JOIN unmnemonic_devices.meetings m ON t.id = m.team_id
                LEFT JOIN unmnemonic_devices.destinations d ON m.destination_id = d.id
                LEFT JOIN unmnemonic_devices.regions r ON d.region_id = r.id
                GROUP BY
                    t.name, complete, t.voicepass, r.name
            ) t
            GROUP BY
                t.name, complete, t.voicepass
            ORDER BY
                t.name;
        "#,
    )
    .fetch_all(&state.db)
    .await
    .expect("Failed to fetch teams");

    RenderHtml(
        key.chars().skip(1).collect::<String>(),
        state.engine,
        Teams { teams },
    )
}
