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
#![allow(unexpected_cfgs)] // Allow flutter_rust_bridge frb_expand cfg

mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */

pub mod adapters;
pub mod api;
pub mod domain;
pub mod ports;
pub mod scheduler;
pub mod state;

// Re-export commonly used types from each module
pub use api::{
    connect_device, create_hr_stream, disconnect, emit_hr_data, init_panic_handler, scan_devices,
    start_mock_mode,
};
pub use domain::{
    is_valid_bpm, parse_heart_rate, DiscoveredDevice, FilteredHeartRate, HeartRateMeasurement,
    KalmanFilter, Zone,
};
pub use ports::BleAdapter;
pub use scheduler::SessionExecutor;
pub use state::{ConnectionEvent, ConnectionState, ConnectionStateMachine};
