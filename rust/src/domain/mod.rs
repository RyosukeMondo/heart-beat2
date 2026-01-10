//! Domain layer containing pure business logic and data types.
//!
//! This module contains all domain models and logic with no I/O dependencies,
//! following hexagonal architecture principles.

pub mod filters;
pub mod heart_rate;
pub mod hrv;

// Re-export key types for convenient access
pub use filters::{is_valid_bpm, KalmanFilter};
pub use heart_rate::{
    parse_heart_rate, DiscoveredDevice, FilteredHeartRate, HeartRateMeasurement, Zone,
};
pub use hrv::{calculate_rmssd, calculate_sdnn};
