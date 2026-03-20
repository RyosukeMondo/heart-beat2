//! Domain layer containing pure business logic and data types.
//!
//! This module contains all domain models and logic with no I/O dependencies,
//! following hexagonal architecture principles.

pub mod adaptive;
pub mod analytics;
pub mod battery;
pub mod export;
pub mod export_formats;
pub mod filters;
pub mod heart_rate;
pub mod hrv;
pub mod periodization;
pub mod readiness;
pub mod reconnection;
pub mod resting_hr;
pub mod session_history;
pub mod session_progress;
pub mod training_load;
pub mod training_plan;
pub mod workout_library;

// Re-export key types for convenient access
pub use adaptive::{
    adapt_plan, compute_adjustment, shift_zone, AdaptedPlan, Adjustment, AdjustmentReason,
};
pub use battery::BatteryLevel;
pub use export::{export_to_csv, export_to_json, export_to_summary};
pub use export_formats::{export_to_gpx, export_to_tcx};
pub use filters::{is_valid_bpm, KalmanFilter};
pub use heart_rate::{
    parse_heart_rate, DiscoveredDevice, FilteredHeartRate, HeartRateMeasurement, Zone,
};
pub use hrv::{calculate_rmssd, calculate_sdnn};
pub use periodization::{
    compute_compliance, create_5k_plan, create_general_fitness_plan, generate_week_schedule,
    BlockType, PeriodizationPlan, ScheduledSession, TrainingBlock,
};
pub use readiness::{
    compute_hrv_baseline, compute_readiness, compute_rhr_baseline, HrvReading, ReadinessLevel,
    ReadinessScore, RestingHrReading,
};
pub use reconnection::{ConnectionStatus, ReconnectionPolicy};
pub use resting_hr::{
    compute_resting_hr_stats, compute_resting_hr_trend, detect_resting_hr_from_session,
    MeasurementSource, RestingHrMeasurement, RestingHrStats, TrendDirection,
};
pub use session_history::{CompletedSession, HrSample, PhaseResult, SessionStatus, SessionSummary};
pub use session_progress::{PhaseProgress, SessionProgress, SessionState, ZoneStatus};
pub use training_load::{
    compute_daily_trimp, compute_session_trimp, compute_training_load, current_training_load,
    DailyTrimp, TrainingLoadMetrics,
};
pub use training_plan::{calculate_zone, TrainingPhase, TrainingPlan, TransitionCondition};
pub use workout_library::{
    get_default_templates, get_templates_by_difficulty, get_templates_by_sport, Difficulty, Sport,
    WorkoutTemplate,
};
