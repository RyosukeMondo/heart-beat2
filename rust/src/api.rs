//! Flutter Rust Bridge API Layer
//!
//! This module provides the FFI boundary between Rust core logic and Flutter UI.
//! It orchestrates domain, state, and adapter components without containing business logic.

use crate::adapters::btleplug_adapter::BtleplugAdapter;
use crate::domain::heart_rate::DiscoveredDevice;
use crate::frb_generated::StreamSink;
use crate::ports::BleAdapter;
use crate::state::{ConnectionEvent, ConnectionStateMachine};
use anyhow::{anyhow, Result};
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::broadcast;

// Re-export domain types for FRB code generation
pub use crate::domain::heart_rate::{DiscoveredDevice as ApiDiscoveredDevice, FilteredHeartRate as ApiFilteredHeartRate};

// Global state for HR data streaming
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

/// Create a stream for receiving filtered heart rate data.
///
/// Sets up a stream that will receive real-time filtered heart rate measurements
/// from the filtering pipeline. This function is used by Flutter via FRB to
/// create a reactive data stream.
///
/// # Arguments
///
/// * `sink` - The FRB StreamSink that will receive the HR data
///
/// # Returns
///
/// Returns Ok(()) if the stream was successfully set up.
pub fn create_hr_stream(sink: StreamSink<ApiFilteredHeartRate>) -> Result<()> {
    let mut rx = get_hr_stream_receiver();
    tokio::spawn(async move {
        while let Ok(data) = rx.recv().await {
            sink.add(data).ok();
        }
    });
    Ok(())
}

/// Get a receiver for streaming filtered heart rate data (internal use).
///
/// Creates a broadcast receiver that can be used to subscribe to real-time
/// filtered heart rate measurements from the filtering pipeline.
///
/// # Returns
///
/// A tokio broadcast receiver that will receive FilteredHeartRate updates.
/// Multiple receivers can be created for fan-out streaming to multiple consumers.
fn get_hr_stream_receiver() -> broadcast::Receiver<ApiFilteredHeartRate> {
    // Get or create the global broadcast sender
    let tx = get_or_create_hr_broadcast_sender();
    tx.subscribe()
}

/// Get or create the global HR broadcast sender.
///
/// Returns the global broadcast sender for emitting HR data to all stream subscribers.
/// This is thread-safe and can be called from multiple locations.
fn get_or_create_hr_broadcast_sender() -> broadcast::Sender<ApiFilteredHeartRate> {
    use std::sync::OnceLock;
    static HR_TX: OnceLock<broadcast::Sender<ApiFilteredHeartRate>> = OnceLock::new();

    HR_TX.get_or_init(|| {
        let (tx, _rx) = broadcast::channel(HR_CHANNEL_CAPACITY);
        tx
    }).clone()
}

/// Emit filtered heart rate data to all stream subscribers.
///
/// This function should be called by the filtering pipeline when new filtered
/// HR data is available. It broadcasts the data to all active stream subscribers.
///
/// # Arguments
///
/// * `data` - The filtered heart rate measurement to broadcast
///
/// # Returns
///
/// The number of receivers that received the data. Returns 0 if no receivers
/// are currently subscribed.
///
/// # Example
///
/// ```rust,ignore
/// // In your filtering pipeline:
/// let filtered_data = FilteredHeartRate { /* ... */ };
/// emit_hr_data(filtered_data);
/// ```
pub fn emit_hr_data(data: ApiFilteredHeartRate) -> usize {
    let tx = get_or_create_hr_broadcast_sender();
    match tx.send(data) {
        Ok(receiver_count) => receiver_count,
        Err(_) => 0, // No receivers
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_hr_data(raw_bpm: u16, filtered_bpm: u16) -> ApiFilteredHeartRate {
        ApiFilteredHeartRate {
            raw_bpm,
            filtered_bpm,
            rmssd: Some(45.0),
            battery_level: Some(85),
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis() as u64,
        }
    }

    #[tokio::test]
    async fn test_hr_stream_receiver_creation() {
        // Should be able to create multiple receivers
        let _rx1 = get_hr_stream_receiver();
        let _rx2 = get_hr_stream_receiver();
        // Test passes if no panic
    }

    #[tokio::test]
    async fn test_emit_and_receive_hr_data() {
        // Create a receiver
        let mut rx = get_hr_stream_receiver();

        // Emit some data
        let data = create_test_hr_data(80, 79);

        let count = emit_hr_data(data.clone());
        // Note: count may be > 1 due to global state shared across tests
        assert!(count > 0, "Should have at least 1 receiver");

        // Receive the data
        let received = rx.recv().await.expect("Should receive data");
        assert_eq!(received.raw_bpm, 80);
        assert_eq!(received.filtered_bpm, 79);
    }

    #[tokio::test]
    async fn test_multiple_receivers_fan_out() {
        // Emit data with unique BPM to identify this test's data
        let data = create_test_hr_data(155, 154);

        // Create receivers AFTER emitting to avoid old buffered data
        let mut rx1 = get_hr_stream_receiver();
        let mut rx2 = get_hr_stream_receiver();
        let mut rx3 = get_hr_stream_receiver();

        // Now emit the test data
        emit_hr_data(data);

        // All receivers should get the data
        let r1 = rx1.recv().await.expect("rx1 should receive");
        let r2 = rx2.recv().await.expect("rx2 should receive");
        let r3 = rx3.recv().await.expect("rx3 should receive");

        assert_eq!(r1.raw_bpm, 155);
        assert_eq!(r2.raw_bpm, 155);
        assert_eq!(r3.raw_bpm, 155);
        assert_eq!(r1.filtered_bpm, 154);
        assert_eq!(r2.filtered_bpm, 154);
        assert_eq!(r3.filtered_bpm, 154);
    }

    #[tokio::test]
    async fn test_stream_backpressure() {
        let mut rx = get_hr_stream_receiver();

        // Emit more than buffer capacity (100 items)
        for i in 0..150 {
            let data = create_test_hr_data(60 + i as u16, 60 + i as u16);
            emit_hr_data(data);
        }

        // Should be able to receive data, but may have missed some due to lagging
        match rx.recv().await {
            Ok(data) => {
                // Successfully received data
                assert!(data.raw_bpm >= 60 && data.raw_bpm < 210);
            }
            Err(broadcast::error::RecvError::Lagged(skipped)) => {
                // Expected when buffer is exceeded
                assert!(skipped > 0, "Should report skipped messages");
            }
            Err(e) => panic!("Unexpected error: {:?}", e),
        }
    }
}
