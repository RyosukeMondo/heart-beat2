//! BLE Adapter Port
//!
//! This module defines the `BleAdapter` trait, which abstracts BLE operations
//! for testability and swappability. This allows the domain logic to work with
//! both real BLE hardware (via btleplug) and simulated data (via MockAdapter).

use crate::domain::heart_rate::DiscoveredDevice;
use anyhow::Result;
use async_trait::async_trait;
use tokio::sync::mpsc::Receiver;

/// Abstraction for BLE operations to enable testing and swappable implementations.
///
/// This trait defines the interface for all BLE-related operations including
/// device discovery, connection management, and data subscription. It is
/// implemented by both the real btleplug adapter and the mock adapter for testing.
#[async_trait]
pub trait BleAdapter: Send + Sync {
    /// Start scanning for BLE devices.
    ///
    /// This initiates a BLE scan that will populate the list of discovered devices.
    /// Devices can be retrieved using `get_discovered_devices()`.
    ///
    /// # Errors
    ///
    /// Returns an error if the BLE adapter fails to start scanning, typically due to
    /// platform-specific BLE issues or permission problems.
    async fn start_scan(&self) -> Result<()>;

    /// Stop scanning for BLE devices.
    ///
    /// This halts the BLE scan initiated by `start_scan()`.
    ///
    /// # Errors
    ///
    /// Returns an error if the BLE adapter fails to stop scanning.
    async fn stop_scan(&self) -> Result<()>;

    /// Get the list of discovered devices from the last scan.
    ///
    /// Returns all devices discovered since `start_scan()` was called.
    /// The list is typically filtered to only include devices advertising
    /// the Heart Rate Service (UUID 0x180D).
    async fn get_discovered_devices(&self) -> Vec<DiscoveredDevice>;

    /// Connect to a BLE device by its device ID.
    ///
    /// # Arguments
    ///
    /// * `device_id` - The unique identifier of the device to connect to
    ///
    /// # Errors
    ///
    /// Returns an error if the device cannot be found or the connection fails.
    async fn connect(&self, device_id: &str) -> Result<()>;

    /// Disconnect from the currently connected BLE device.
    ///
    /// # Errors
    ///
    /// Returns an error if disconnection fails or no device is currently connected.
    async fn disconnect(&self) -> Result<()>;

    /// Subscribe to heart rate notifications.
    ///
    /// This subscribes to the Heart Rate Measurement characteristic (UUID 0x2A37)
    /// and returns a channel receiver that will receive raw BLE notification data.
    /// Each message contains the raw bytes from the heart rate characteristic.
    ///
    /// # Returns
    ///
    /// A receiver that will receive `Vec<u8>` packets containing raw heart rate
    /// measurement data according to the Bluetooth SIG Heart Rate Measurement format.
    ///
    /// # Errors
    ///
    /// Returns an error if the subscription fails, typically because no device is
    /// connected or the device doesn't support the Heart Rate Service.
    async fn subscribe_hr(&self) -> Result<Receiver<Vec<u8>>>;

    /// Read the battery level from the connected device.
    ///
    /// Reads the Battery Level characteristic (if available) from the connected device.
    ///
    /// # Returns
    ///
    /// Battery level as a percentage (0-100), or `None` if the device doesn't
    /// support the Battery Service.
    ///
    /// # Errors
    ///
    /// Returns an error if the read fails due to connection issues, but returns
    /// `Ok(None)` if the Battery Service is not found.
    async fn read_battery(&self) -> Result<Option<u8>>;
}
