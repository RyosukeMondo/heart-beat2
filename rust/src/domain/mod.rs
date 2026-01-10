//! Domain layer containing pure business logic and data types.
//!
//! This module contains all domain models and logic with no I/O dependencies,
//! following hexagonal architecture principles.

pub mod filters;
pub mod heart_rate;

// Re-export key types for convenient access
pub use filters::KalmanFilter;
pub use heart_rate::{HeartRateMeasurement, Zone};
