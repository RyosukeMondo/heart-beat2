//! Flutter Rust Bridge API Layer
//!
//! This module provides the FFI boundary between Rust core logic and Flutter UI.
//! It orchestrates domain, state, and adapter components without containing business logic.

use crate::adapters::btleplug_adapter::BtleplugAdapter;
use crate::domain::heart_rate::DiscoveredDevice;
use crate::ports::BleAdapter;
use crate::state::{ConnectionEvent, ConnectionStateMachine};
use anyhow::{anyhow, Result};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::broadcast;

// Re-export domain types for FRB code generation
pub use crate::domain::heart_rate::{DiscoveredDevice as ApiDiscoveredDevice, FilteredHeartRate as ApiFilteredHeartRate};

// Global broadcast channel for HR data streaming
// In production, this would be initialized once and stored in global state
static HR_CHANNEL_CAPACITY: usize = 100;

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
    // Create BtleplugAdapter instance
    let adapter = Arc::new(BtleplugAdapter::new().await?);

    // Create state machine with adapter
    let mut state_machine = ConnectionStateMachine::new(adapter.clone());

    // Send DeviceSelected event to initiate connection
    state_machine.handle(ConnectionEvent::DeviceSelected {
        device_id: device_id.clone(),
    })?;

    // Attempt to connect using the adapter
    let connect_result = tokio::time::timeout(
        Duration::from_secs(15),
        adapter.connect(&device_id),
    )
    .await;

    match connect_result {
        Ok(Ok(())) => {
            // Connection successful, signal the state machine
            state_machine.handle(ConnectionEvent::ConnectionSuccess)?;

            // Discover services
            state_machine.handle(ConnectionEvent::ServicesDiscovered)?;

            Ok(())
        }
        Ok(Err(e)) => {
            // Connection failed
            state_machine.handle(ConnectionEvent::ConnectionFailed)?;
            Err(anyhow!("Connection failed: {}", e))
        }
        Err(_) => {
            // Timeout
            state_machine.handle(ConnectionEvent::ConnectionFailed)?;
            Err(anyhow!("Connection timeout after 15 seconds"))
        }
    }
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
    // Note: In a real implementation, we would need to maintain a global
    // connection state or pass the adapter/state machine as context.
    // For now, this is a placeholder that assumes the caller manages state.
    Err(anyhow!("Disconnect not yet implemented - requires global state management"))
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

/// Create a broadcast channel for streaming heart rate data.
///
/// Returns a receiver that can be used to subscribe to filtered heart rate updates.
/// Multiple receivers can subscribe to the same channel for fan-out streaming.
///
/// # Implementation Note
///
/// This function creates a tokio broadcast channel suitable for streaming HR data
/// to Flutter via FRB StreamSink. The full implementation requires:
/// 1. A global state manager to hold the sender
/// 2. Integration with the filtering pipeline (BLE -> parse -> filter -> HRV)
/// 3. FRB StreamSink wrapper to bridge Rust receiver to Dart Stream
///
/// # Returns
///
/// A broadcast receiver that will receive FilteredHeartRate updates.
///
/// # Example Integration Pattern
///
/// ```rust,ignore
/// // In FRB-enabled code:
/// #[frb]
/// pub fn create_hr_stream() -> StreamSink<FilteredHeartRate> {
///     let rx = create_hr_broadcast_receiver();
///     StreamSink::from_receiver(rx)
/// }
/// ```
pub fn create_hr_broadcast_receiver() -> broadcast::Receiver<crate::domain::heart_rate::FilteredHeartRate> {
    // Create a broadcast channel with capacity for 100 buffered events
    let (tx, rx) = broadcast::channel(HR_CHANNEL_CAPACITY);

    // TODO: Store tx in global state for the pipeline to send to
    // For now, just return the receiver
    drop(tx); // Prevent unused variable warning

    rx
}
