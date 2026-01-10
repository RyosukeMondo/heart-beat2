//! Flutter Rust Bridge API Layer
//!
//! This module provides the FFI boundary between Rust core logic and Flutter UI.
//! It orchestrates domain, state, and adapter components without containing business logic.

use crate::adapters::btleplug_adapter::BtleplugAdapter;
use crate::domain::heart_rate::DiscoveredDevice;
use crate::ports::BleAdapter;
use anyhow::Result;
use std::time::Duration;

// Re-export domain types for FRB code generation
pub use crate::domain::heart_rate::{DiscoveredDevice as ApiDiscoveredDevice, FilteredHeartRate as ApiFilteredHeartRate};

/// Scan for BLE heart rate devices.
///
/// Initiates a BLE scan and returns all discovered devices advertising
/// the Heart Rate Service (UUID 0x180D).
///
/// # Returns
///
/// A list of discovered devices with their IDs, names, and signal strength.
///
/// # Errors
///
/// Returns an error if:
/// - BLE adapter initialization fails
/// - Scan operation fails
/// - BLE is not available or permissions are missing
pub async fn scan_devices() -> Result<Vec<DiscoveredDevice>> {
    // Create btleplug adapter instance
    let adapter = BtleplugAdapter::new().await?;

    // Start scanning
    adapter.start_scan().await?;

    // Wait for scan to collect devices
    tokio::time::sleep(Duration::from_secs(10)).await;

    // Stop scanning and get results
    adapter.stop_scan().await?;
    let devices = adapter.get_discovered_devices().await;

    Ok(devices)
}

/// Connect to a BLE heart rate device.
///
/// Establishes a connection to the specified device and transitions the
/// connectivity state machine to the Connected state.
///
/// # Arguments
///
/// * `device_id` - Platform-specific device identifier from scan results
///
/// # Errors
///
/// Returns an error if:
/// - Device is not found
/// - Connection fails
/// - Connection timeout (15 seconds)
pub async fn connect_device(device_id: String) -> Result<()> {
    // TODO: Implement using state machine
    let _ = device_id;
    Ok(())
}

/// Disconnect from the currently connected device.
///
/// Gracefully disconnects from the active BLE connection and transitions
/// the state machine back to Idle.
///
/// # Errors
///
/// Returns an error if disconnection fails or no device is connected.
pub async fn disconnect() -> Result<()> {
    // TODO: Implement
    Ok(())
}

/// Start mock mode for testing without hardware.
///
/// Activates the mock adapter which generates simulated heart rate data.
/// Useful for UI development and testing without a physical device.
///
/// # Errors
///
/// Returns an error if mock mode activation fails.
pub async fn start_mock_mode() -> Result<()> {
    // TODO: Implement using MockAdapter
    Ok(())
}
