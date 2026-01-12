//! Port traits for the HR Telemetry system.
//!
//! This module contains trait definitions that abstract external dependencies
//! and I/O operations, following the hexagonal architecture pattern. These
//! traits enable dependency injection and testing with mock implementations.

pub mod ble_adapter;
pub mod notification;
pub mod session_repository;

pub use ble_adapter::BleAdapter;
pub use notification::*;
pub use session_repository::{SessionRepository, SessionSummaryPreview};
