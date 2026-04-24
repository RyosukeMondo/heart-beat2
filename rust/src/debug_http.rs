//! Debug HTTP server — axum Router + all handler functions.
//!
//! This module is the core of both the standalone debug-server binary and the
//! embedded debug server started from the Flutter app.

use crate::api;
use crate::logging;
use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        Path, Query,
    },
    http::StatusCode,
    response::IntoResponse,
    routing::{delete, get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Instant;

/// Exposed so the binary can set this before calling `build_router()`.
pub static START_TIME: std::sync::OnceLock<Instant> = std::sync::OnceLock::new();

/// Track mock mode for the health endpoint.
pub static MOCK_STARTED: AtomicBool = AtomicBool::new(false);

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

pub fn build_router() -> Router {
    Router::new()
        // === Device routes ===
        .route("/api/devices/scan", post(devices_scan))
        .route("/api/devices/connect", post(devices_connect))
        .route("/api/devices/disconnect", post(devices_disconnect))
        // === Workout routes ===
        .route("/api/workout/start", post(workout_start))
        .route("/api/workout/pause", post(workout_pause))
        .route("/api/workout/resume", post(workout_resume))
        .route("/api/workout/stop", post(workout_stop))
        .route("/api/workout/start-template", post(workout_start_template))
        // === Session routes ===
        .route("/api/sessions", get(sessions_list))
        .route("/api/sessions/{id}", get(session_get))
        .route("/api/sessions/{id}", delete(session_delete))
        .route("/api/sessions/{id}/export", get(session_export))
        .route("/api/sessions/{id}/export/tcx", get(session_export_tcx))
        .route("/api/sessions/{id}/export/gpx", get(session_export_gpx))
        // === Plan routes ===
        .route("/api/plans", get(plans_list))
        .route("/api/plans", post(plan_create))
        .route("/api/plans/seed", post(plans_seed))
        .route("/api/plans/{name}", get(plan_details))
        .route("/api/plans/{name}", delete(plan_delete))
        .route("/api/plans/{name}/adapted", get(plan_adapted))
        // === Analytics routes ===
        .route("/api/analytics", get(analytics_get))
        .route("/api/analytics/training-load", get(analytics_training_load))
        .route("/api/analytics/readiness", get(analytics_readiness))
        .route("/api/analytics/resting-hr", get(analytics_resting_hr))
        .route("/api/analytics/periodization", get(analytics_periodization))
        // === Library routes ===
        .route("/api/library/templates", get(library_templates))
        // === Debug routes ===
        .route("/debug/health", get(debug_health))
        .route("/debug/logs", get(debug_logs))
        .route("/debug/state", get(debug_state))
        .route("/debug/mock/start", post(debug_mock_start))
        // === WebSocket routes ===
        .route("/ws/hr", get(ws_hr))
        .route("/ws/battery", get(ws_battery))
        .route("/ws/progress", get(ws_progress))
        .route("/ws/connection", get(ws_connection))
        .route("/ws/logs", get(ws_logs))
        .layer(tower_http::cors::CorsLayer::permissive())
}

// ---------------------------------------------------------------------------
// JSON envelope
// ---------------------------------------------------------------------------

#[derive(Serialize)]
pub struct ApiOk<T: Serialize> {
    ok: bool,
    data: T,
}

#[derive(Serialize)]
pub struct ApiErr {
    ok: bool,
    error: String,
}

pub fn ok_json<T: Serialize>(data: T) -> Json<ApiOk<T>> {
    Json(ApiOk { ok: true, data })
}

pub fn err_json(status: StatusCode, msg: impl ToString) -> (StatusCode, Json<ApiErr>) {
    (
        status,
        Json(ApiErr {
            ok: false,
            error: msg.to_string(),
        }),
    )
}

pub type ApiResult<T> = Result<Json<ApiOk<T>>, (StatusCode, Json<ApiErr>)>;

pub fn map_err(e: anyhow::Error) -> (StatusCode, Json<ApiErr>) {
    err_json(StatusCode::INTERNAL_SERVER_ERROR, e)
}

// ---------------------------------------------------------------------------
// Device handlers
// ---------------------------------------------------------------------------

async fn devices_scan() -> ApiResult<Vec<api::ApiDiscoveredDevice>> {
    api::scan_devices().await.map(ok_json).map_err(map_err)
}

#[derive(Deserialize)]
pub struct ConnectBody {
    pub device_id: String,
}

async fn devices_connect(Json(body): Json<ConnectBody>) -> ApiResult<&'static str> {
    api::connect_device(body.device_id)
        .await
        .map(|_| ok_json("connected"))
        .map_err(map_err)
}

async fn devices_disconnect() -> ApiResult<&'static str> {
    api::disconnect()
        .await
        .map(|_| ok_json("disconnected"))
        .map_err(map_err)
}

// ---------------------------------------------------------------------------
// Workout handlers
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
pub struct WorkoutStartBody {
    pub plan_name: String,
}

async fn workout_start(Json(body): Json<WorkoutStartBody>) -> ApiResult<&'static str> {
    api::start_workout(body.plan_name)
        .await
        .map(|_| ok_json("started"))
        .map_err(map_err)
}

async fn workout_pause() -> ApiResult<&'static str> {
    api::pause_workout()
        .await
        .map(|_| ok_json("paused"))
        .map_err(map_err)
}

async fn workout_resume() -> ApiResult<&'static str> {
    api::resume_workout()
        .await
        .map(|_| ok_json("resumed"))
        .map_err(map_err)
}

async fn workout_stop() -> ApiResult<&'static str> {
    api::stop_workout()
        .await
        .map(|_| ok_json("stopped"))
        .map_err(map_err)
}

#[derive(Deserialize)]
pub struct TemplateStartBody {
    pub template_id: String,
    pub max_hr: u16,
}

async fn workout_start_template(Json(body): Json<TemplateStartBody>) -> ApiResult<&'static str> {
    api::start_template_workout(body.template_id, body.max_hr)
        .await
        .map(|_| ok_json("started"))
        .map_err(map_err)
}

// ---------------------------------------------------------------------------
// Session handlers
// ---------------------------------------------------------------------------

async fn sessions_list() -> ApiResult<Vec<api::ApiSessionSummaryPreview>> {
    api::list_sessions().await.map(ok_json).map_err(map_err)
}

async fn session_get(Path(id): Path<String>) -> ApiResult<Option<api::ApiCompletedSession>> {
    api::get_session(id).await.map(ok_json).map_err(map_err)
}

async fn session_delete(Path(id): Path<String>) -> ApiResult<&'static str> {
    api::delete_session(id)
        .await
        .map(|_| ok_json("deleted"))
        .map_err(map_err)
}

#[derive(Deserialize)]
pub struct ExportQuery {
    pub format: Option<String>,
}

async fn session_export(Path(id): Path<String>, Query(q): Query<ExportQuery>) -> ApiResult<String> {
    let format = match q.format.as_deref() {
        Some("json") => api::ExportFormat::Json,
        Some("summary") => api::ExportFormat::Summary,
        _ => api::ExportFormat::Csv,
    };
    api::export_session(id, format)
        .await
        .map(ok_json)
        .map_err(map_err)
}

async fn session_export_tcx(Path(id): Path<String>) -> ApiResult<String> {
    api::export_session_tcx(id)
        .await
        .map(ok_json)
        .map_err(map_err)
}

async fn session_export_gpx(Path(id): Path<String>) -> ApiResult<String> {
    api::export_session_gpx(id)
        .await
        .map(ok_json)
        .map_err(map_err)
}

// ---------------------------------------------------------------------------
// Plan handlers
// ---------------------------------------------------------------------------

async fn plans_list() -> ApiResult<Vec<String>> {
    api::list_plans().await.map(ok_json).map_err(map_err)
}

async fn plan_details(Path(name): Path<String>) -> ApiResult<api::ApiPlanDetails> {
    api::get_plan_details(name)
        .await
        .map(ok_json)
        .map_err(map_err)
}

#[derive(Deserialize)]
pub struct CreatePlanBody {
    pub name: String,
    pub phase_names: Vec<String>,
    pub phase_zones: Vec<u8>,
    pub phase_durations: Vec<u32>,
    pub max_hr: u16,
}

async fn plan_create(Json(body): Json<CreatePlanBody>) -> ApiResult<&'static str> {
    api::create_custom_plan(
        body.name,
        body.phase_names,
        body.phase_zones,
        body.phase_durations,
        body.max_hr,
    )
    .await
    .map(|_| ok_json("created"))
    .map_err(map_err)
}

async fn plan_delete(Path(name): Path<String>) -> ApiResult<&'static str> {
    api::delete_plan(name)
        .await
        .map(|_| ok_json("deleted"))
        .map_err(map_err)
}

async fn plans_seed() -> ApiResult<u32> {
    api::seed_default_plans()
        .await
        .map(ok_json)
        .map_err(map_err)
}

async fn plan_adapted(Path(name): Path<String>) -> ApiResult<api::ApiAdaptedPlan> {
    api::get_adapted_plan(name)
        .await
        .map(ok_json)
        .map_err(map_err)
}

// ---------------------------------------------------------------------------
// Analytics handlers
// ---------------------------------------------------------------------------

#[derive(Serialize)]
struct AnalyticsResponse {
    summary: api::ApiAnalyticsSummary,
    weekly_count: u32,
    hr_trend_count: u32,
    volume_trend_count: u32,
}

async fn analytics_get() -> ApiResult<AnalyticsResponse> {
    let data = api::get_analytics().await.map_err(map_err)?;
    Ok(ok_json(AnalyticsResponse {
        weekly_count: data.weekly_summaries.len() as u32,
        hr_trend_count: data.hr_trend.len() as u32,
        volume_trend_count: data.volume_trend.len() as u32,
        summary: api::analytics_summary(&data),
    }))
}

async fn analytics_training_load() -> ApiResult<api::ApiTrainingLoadData> {
    api::get_training_load().await.map(ok_json).map_err(map_err)
}

async fn analytics_readiness() -> ApiResult<api::ApiReadinessData> {
    api::get_readiness_score()
        .await
        .map(|v| ok_json(v))
        .map_err(map_err)
}

async fn analytics_resting_hr() -> ApiResult<api::ApiRestingHrStats> {
    api::get_resting_hr_stats()
        .await
        .map(|v| ok_json(v))
        .map_err(map_err)
}

async fn analytics_periodization() -> ApiResult<api::ApiPeriodizationData> {
    Ok(ok_json(api::get_periodization_plan()))
}

// ---------------------------------------------------------------------------
// Library handlers
// ---------------------------------------------------------------------------

async fn library_templates() -> ApiResult<Vec<api::ApiWorkoutTemplate>> {
    Ok(ok_json(api::get_workout_templates()))
}

// ---------------------------------------------------------------------------
// Debug handlers
// ---------------------------------------------------------------------------

#[derive(Serialize)]
pub struct HealthResponse {
    status: &'static str,
    uptime_secs: u64,
    version: &'static str,
    mock_mode: bool,
}

async fn debug_health() -> Json<ApiOk<HealthResponse>> {
    let uptime = START_TIME.get().map(|t| t.elapsed().as_secs()).unwrap_or(0);
    ok_json(HealthResponse {
        status: "ok",
        uptime_secs: uptime,
        version: env!("CARGO_PKG_VERSION"),
        mock_mode: MOCK_STARTED.load(Ordering::Relaxed),
    })
}

#[derive(Deserialize)]
pub struct LogsQuery {
    pub level: Option<String>,
    pub source: Option<String>,
    pub limit: Option<usize>,
}

async fn debug_logs(Query(q): Query<LogsQuery>) -> ApiResult<Vec<api::LogMessage>> {
    let limit = q.limit.unwrap_or(100).min(1000);
    let logs = logging::get_recent_logs(q.level.as_deref(), q.source.as_deref(), limit);
    Ok(ok_json(logs))
}

#[derive(Serialize)]
pub struct StateResponse {
    sessions_count: usize,
    plans_count: usize,
}

async fn debug_state() -> ApiResult<StateResponse> {
    let sessions = api::list_sessions().await.map_err(map_err)?.len();
    let plans = api::list_plans().await.map_err(map_err)?.len();
    Ok(ok_json(StateResponse {
        sessions_count: sessions,
        plans_count: plans,
    }))
}

async fn debug_mock_start() -> ApiResult<&'static str> {
    MOCK_STARTED.store(true, Ordering::Relaxed);
    api::start_mock_mode()
        .await
        .map(|_| ok_json("mock_started"))
        .map_err(map_err)
}

// ---------------------------------------------------------------------------
// WebSocket handlers
// ---------------------------------------------------------------------------

async fn ws_hr(ws: WebSocketUpgrade) -> impl IntoResponse {
    ws.on_upgrade(handle_ws_hr)
}

async fn handle_ws_hr(mut socket: WebSocket) {
    let mut rx = api::subscribe_hr_stream();
    while let Ok(data) = rx.recv().await {
        let json = serde_json::to_string(&data).unwrap_or_default();
        if socket.send(Message::Text(json)).await.is_err() {
            break;
        }
    }
}

async fn ws_battery(ws: WebSocketUpgrade) -> impl IntoResponse {
    ws.on_upgrade(handle_ws_battery)
}

async fn handle_ws_battery(mut socket: WebSocket) {
    let mut rx = api::subscribe_battery_stream();
    while let Ok(data) = rx.recv().await {
        let json = serde_json::to_string(&data).unwrap_or_default();
        if socket.send(Message::Text(json)).await.is_err() {
            break;
        }
    }
}

async fn ws_progress(ws: WebSocketUpgrade) -> impl IntoResponse {
    ws.on_upgrade(handle_ws_progress)
}

async fn handle_ws_progress(mut socket: WebSocket) {
    let mut rx = api::subscribe_session_progress_stream();
    while let Ok(data) = rx.recv().await {
        let json = serde_json::to_string(&data).unwrap_or_default();
        if socket.send(Message::Text(json)).await.is_err() {
            break;
        }
    }
}

async fn ws_connection(ws: WebSocketUpgrade) -> impl IntoResponse {
    ws.on_upgrade(handle_ws_connection)
}

async fn handle_ws_connection(mut socket: WebSocket) {
    let mut rx = api::subscribe_connection_status_stream();
    while let Ok(data) = rx.recv().await {
        let json = serde_json::to_string(&data).unwrap_or_default();
        if socket.send(Message::Text(json)).await.is_err() {
            break;
        }
    }
}

async fn ws_logs(ws: WebSocketUpgrade) -> impl IntoResponse {
    ws.on_upgrade(handle_ws_logs)
}

async fn handle_ws_logs(mut socket: WebSocket) {
    // Read optional filter config from first message
    let (level_filter, source_filter) = match socket.recv().await {
        Some(Ok(Message::Text(text))) => {
            if let Ok(config) = serde_json::from_str::<WsLogConfig>(&text) {
                (config.level, config.source)
            } else {
                (None, None)
            }
        }
        _ => (None, None),
    };

    let mut rx = logging::subscribe_log_stream();
    while let Ok(msg) = rx.recv().await {
        // Filter by level if specified
        if let Some(ref min_level) = level_filter {
            let min_ord = level_ordinal(min_level);
            if level_ordinal(&msg.level) < min_ord {
                continue;
            }
        }
        // Filter by source if specified
        if let Some(ref source) = source_filter {
            if !msg.target.to_lowercase().contains(&source.to_lowercase()) {
                continue;
            }
        }

        let json = serde_json::to_string(&msg).unwrap_or_default();
        if socket.send(Message::Text(json)).await.is_err() {
            break;
        }
    }
}

#[derive(serde::Deserialize)]
struct WsLogConfig {
    level: Option<String>,
    source: Option<String>,
}

fn level_ordinal(level: &str) -> u8 {
    match level.to_uppercase().as_str() {
        "TRACE" => 0,
        "DEBUG" => 1,
        "INFO" => 2,
        "WARN" | "WARNING" => 3,
        "ERROR" => 4,
        _ => 2,
    }
}