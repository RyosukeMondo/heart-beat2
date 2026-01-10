//! Heart Beat - HR Telemetry Core Library
//!
//! This library provides heart rate monitoring and telemetry functionality
//! with BLE device integration, signal processing, and state management.
//!
//! # Architecture
//!
//! This crate follows hexagonal architecture with clear separation between:
//! - **Domain**: Pure business logic and data types
//! - **Ports**: Trait definitions for external dependencies
//! - **Adapters**: Concrete implementations of ports
//! - **State**: State machines for lifecycle management
//!
//! # Quick Start
//!
//! ```rust,no_run
//! use heart_beat::{adapters::MockAdapter, domain::KalmanFilter};
//!
//! #[tokio::main]
//! async fn main() -> anyhow::Result<()> {
//!     // Create a mock adapter for testing
//!     let adapter = MockAdapter::new();
//!     let mut filter = KalmanFilter::new(0.1, 2.0);
//!
//!     // Use the adapter to stream HR data
//!     Ok(())
//! }
//! ```

#![warn(missing_docs)]

pub mod adapters;
pub mod api;
pub mod domain;
pub mod ports;
pub mod state;

// Re-export commonly used types from each module
pub use api::{
    connect_device, disconnect, emit_hr_data, get_hr_stream_receiver, scan_devices,
    start_mock_mode,
};
pub use domain::{
    is_valid_bpm, parse_heart_rate, DiscoveredDevice, FilteredHeartRate, HeartRateMeasurement,
    KalmanFilter, Zone,
};
pub use ports::BleAdapter;
pub use state::{ConnectionEvent, ConnectionState, ConnectionStateMachine};
