//! BLE adapter implementations.
//!
//! This module contains concrete implementations of the `BleAdapter` trait,
//! including both real hardware adapters and mock adapters for testing.

pub mod btleplug_adapter;
pub mod mock_adapter;

pub use btleplug_adapter::BtleplugAdapter;
pub use mock_adapter::{MockAdapter, MockConfig};
