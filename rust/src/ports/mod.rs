//! Port traits for the HR Telemetry system.
//!
//! This module contains trait definitions that abstract external dependencies
//! and I/O operations, following the hexagonal architecture pattern. These
//! traits enable dependency injection and testing with mock implementations.

pub mod ble_adapter;

pub use ble_adapter::BleAdapter;
