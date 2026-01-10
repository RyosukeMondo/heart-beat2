//! Adapter implementations.
//!
//! This module contains concrete implementations of port traits,
//! including both real hardware adapters and mock adapters for testing.

pub mod btleplug_adapter;
pub mod mock_adapter;
pub mod mock_notification_adapter;

pub use btleplug_adapter::BtleplugAdapter;
pub use mock_adapter::{MockAdapter, MockConfig};
pub use mock_notification_adapter::MockNotificationAdapter;
