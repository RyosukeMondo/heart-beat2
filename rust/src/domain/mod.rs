//! Domain layer containing pure business logic and data types.
//!
//! This module contains all domain models and logic with no I/O dependencies,
//! following hexagonal architecture principles.

pub mod battery;
pub mod export;
pub mod filters;
pub mod heart_rate;
pub mod hrv;
pub mod session_history;
pub mod session_progress;
pub mod training_plan;

// Re-export key types for convenient access
pub use battery::BatteryLevel;
pub use export::{export_to_csv, export_to_json, export_to_summary};
pub use filters::{is_valid_bpm, KalmanFilter};
pub use heart_rate::{
    parse_heart_rate, DiscoveredDevice, FilteredHeartRate, HeartRateMeasurement, Zone,
};
pub use hrv::{calculate_rmssd, calculate_sdnn};
pub use session_history::{CompletedSession, HrSample, PhaseResult, SessionStatus, SessionSummary};
pub use session_progress::{PhaseProgress, SessionProgress, SessionState, ZoneStatus};
pub use training_plan::{calculate_zone, TrainingPhase, TrainingPlan, TransitionCondition};
