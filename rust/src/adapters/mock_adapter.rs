//! Mock BLE adapter for testing without hardware.
//!
//! This module provides a simulated BLE adapter that generates realistic heart rate
//! data for testing and development purposes. It implements the same `BleAdapter` trait
//! as the real btleplug adapter, allowing the application to work without physical
//! heart rate monitor hardware.

use crate::domain::heart_rate::DiscoveredDevice;
use crate::ports::ble_adapter::BleAdapter;
use anyhow::{anyhow, Result};
use async_trait::async_trait;
use rand::Rng;
use std::sync::Arc;
use tokio::sync::{mpsc, Mutex};
use tokio::time::{self, Duration};

/// Configuration for the mock adapter's simulated data.
///
/// This allows customization of the simulated heart rate patterns for
/// different testing scenarios (e.g., resting, exercise, recovery).
#[derive(Debug, Clone)]
pub struct MockConfig {
    /// Baseline heart rate in BPM around which the simulation oscillates.
    pub baseline_bpm: u16,

    /// Maximum noise added to the baseline (+/- this value).
    pub noise_range: u16,

    /// Probability (0.0-1.0) of generating an occasional spike.
    pub spike_probability: f64,

    /// Size of spikes when they occur (added to baseline + noise).
    pub spike_magnitude: u16,

    /// Update rate for heart rate notifications (in Hz).
    pub update_rate: f64,

    /// Battery level (0-100) to simulate.
    pub battery_level: u8,
}

impl Default for MockConfig {
    fn default() -> Self {
        Self {
            baseline_bpm: 70,
            noise_range: 5,
            spike_probability: 0.05, // 5% chance
            spike_magnitude: 20,
            update_rate: 1.0, // 1 Hz
            battery_level: 85,
        }
    }
}

/// Mock BLE adapter that simulates heart rate data.
///
/// This adapter generates realistic heart rate patterns without requiring physical
/// hardware. It's useful for:
/// - Development without a heart rate monitor
/// - Automated testing
/// - Demonstrating the application's behavior
/// - Testing edge cases (connection loss, battery levels, etc.)
pub struct MockAdapter {
    /// Configuration for simulated data generation
    config: MockConfig,
    /// List of fake devices available for discovery
    discovered_devices: Arc<Mutex<Vec<DiscoveredDevice>>>,
    /// Whether a device is currently "connected"
    is_connected: Arc<Mutex<bool>>,
    /// ID of the connected device (if any)
    connected_device_id: Arc<Mutex<Option<String>>>,
}

impl MockAdapter {
    /// Create a new mock adapter with default configuration.
    pub fn new() -> Self {
        Self::with_config(MockConfig::default())
    }

    /// Create a new mock adapter with custom configuration.
    ///
    /// # Arguments
    ///
    /// * `config` - Configuration for simulated heart rate patterns
    pub fn with_config(config: MockConfig) -> Self {
        Self {
            config,
            discovered_devices: Arc::new(Mutex::new(Vec::new())),
            is_connected: Arc::new(Mutex::new(false)),
            connected_device_id: Arc::new(Mutex::new(None)),
        }
    }

    /// Simulate the HR notification stream.
    ///
    /// This spawns a background task that generates heart rate packets at the
    /// configured update rate and sends them through the channel.
    fn start_hr_stream(&self, tx: mpsc::Sender<Vec<u8>>) {
        let config = self.config.clone();
        let is_connected = self.is_connected.clone();

        tokio::spawn(async move {
            let interval_duration = Duration::from_secs_f64(1.0 / config.update_rate);
            let mut interval = time::interval(interval_duration);

            loop {
                interval.tick().await;

                // Stop streaming if disconnected
                if !*is_connected.lock().await {
                    tracing::debug!("Mock adapter: Connection closed, stopping HR stream");
                    break;
                }

                // Generate and send packet
                let packet = Self::generate_hr_packet_static(&config);
                if tx.send(packet).await.is_err() {
                    tracing::debug!("Mock adapter: HR receiver dropped");
                    break;
                }
            }
        });
    }

    /// Generate a simulated heart rate measurement packet.
    ///
    /// This creates a packet following the Bluetooth Heart Rate Measurement format:
    /// - Byte 0: Flags
    /// - Byte 1-2: Heart rate value (UINT8 or UINT16 depending on flags)
    /// - Remaining bytes: RR-intervals (optional)
    ///
    /// The generated data is designed to be parsed by the same parser that handles
    /// real BLE data, ensuring test coverage of the parsing logic.
    fn generate_hr_packet_static(config: &MockConfig) -> Vec<u8> {
        let mut rng = rand::thread_rng();

        let noise: i16 = rng.gen_range(-(config.noise_range as i16)..=(config.noise_range as i16));
        let mut bpm = (config.baseline_bpm as i16 + noise).max(30) as u16;

        if rng.gen::<f64>() < config.spike_probability {
            bpm = (bpm + config.spike_magnitude).min(220);
        }

        let flags: u8 = 0b00010110;
        let mut packet = vec![flags, bpm as u8];

        let beat_interval_ms = 60000.0 / (bpm as f64);
        let rr_base = (beat_interval_ms * 1.024) as u16;

        let num_intervals = rng.gen_range(1..=2);
        for _ in 0..num_intervals {
            let rr_noise: i16 = rng.gen_range(-50..=50);
            let rr_interval = ((rr_base as i16 + rr_noise).max(300) as u16).min(2000);

            packet.push((rr_interval & 0xFF) as u8);
            packet.push((rr_interval >> 8) as u8);
        }

        packet
    }
}

impl Default for MockAdapter {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait]
impl BleAdapter for MockAdapter {
    async fn start_scan(&self) -> Result<()> {
        tracing::debug!("Mock adapter: Starting scan");

        // Simulate discovering a fake heart rate monitor
        let devices = vec![
            DiscoveredDevice {
                id: "mock-device-001".to_string(),
                name: Some("Mock HR Monitor".to_string()),
                rssi: -65,
            },
            DiscoveredDevice {
                id: "mock-device-002".to_string(),
                name: Some("Simulated HRM".to_string()),
                rssi: -72,
            },
        ];

        *self.discovered_devices.lock().await = devices;

        Ok(())
    }

    async fn stop_scan(&self) -> Result<()> {
        tracing::debug!("Mock adapter: Stopping scan");
        Ok(())
    }

    async fn get_discovered_devices(&self) -> Vec<DiscoveredDevice> {
        self.discovered_devices.lock().await.clone()
    }

    async fn connect(&self, device_id: &str) -> Result<()> {
        tracing::debug!("Mock adapter: Connecting to {}", device_id);

        // Check if device exists in discovered list
        let devices = self.discovered_devices.lock().await;
        let device_exists = devices.iter().any(|d| d.id == device_id);

        if !device_exists {
            return Err(anyhow!("Device not found: {}", device_id));
        }

        // Simulate connection delay
        time::sleep(Duration::from_millis(500)).await;

        *self.is_connected.lock().await = true;
        *self.connected_device_id.lock().await = Some(device_id.to_string());

        tracing::info!("Mock adapter: Connected to {}", device_id);
        Ok(())
    }

    async fn disconnect(&self) -> Result<()> {
        let device_id = self.connected_device_id.lock().await.take();

        if device_id.is_none() {
            return Err(anyhow!("No device connected"));
        }

        *self.is_connected.lock().await = false;

        tracing::info!("Mock adapter: Disconnected from {:?}", device_id);
        Ok(())
    }

    async fn subscribe_hr(&self) -> Result<mpsc::Receiver<Vec<u8>>> {
        if !*self.is_connected.lock().await {
            return Err(anyhow!("No device connected"));
        }

        tracing::debug!("Mock adapter: Subscribing to HR notifications");

        // Create channel for HR data
        let (tx, rx) = mpsc::channel(32);

        // Start the simulated HR stream
        self.start_hr_stream(tx);

        Ok(rx)
    }

    async fn read_battery(&self) -> Result<u8> {
        if !*self.is_connected.lock().await {
            return Err(anyhow!("No device connected"));
        }

        tracing::debug!("Mock adapter: Reading battery level");

        // Simulate read delay
        time::sleep(Duration::from_millis(100)).await;

        Ok(self.config.battery_level)
    }
}

#[cfg(test)]
#[allow(clippy::useless_vec)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_scan_discovers_devices() {
        let adapter = MockAdapter::new();

        adapter.start_scan().await.unwrap();
        let devices = adapter.get_discovered_devices().await;

        assert!(!devices.is_empty(), "Should discover at least one device");
        assert!(
            devices.iter().any(|d| d.name.is_some()),
            "At least one device should have a name"
        );
    }

    #[tokio::test]
    async fn test_connect_to_discovered_device() {
        let adapter = MockAdapter::new();

        adapter.start_scan().await.unwrap();
        let devices = adapter.get_discovered_devices().await;
        let device_id = &devices[0].id;

        let result = adapter.connect(device_id).await;
        assert!(result.is_ok(), "Should connect to discovered device");

        let is_connected = *adapter.is_connected.lock().await;
        assert!(is_connected, "Should be marked as connected");
    }

    #[tokio::test]
    async fn test_connect_to_unknown_device_fails() {
        let adapter = MockAdapter::new();

        adapter.start_scan().await.unwrap();
        let result = adapter.connect("unknown-device").await;

        assert!(result.is_err(), "Should fail to connect to unknown device");
    }

    #[tokio::test]
    async fn test_disconnect() {
        let adapter = MockAdapter::new();

        adapter.start_scan().await.unwrap();
        let devices = adapter.get_discovered_devices().await;
        adapter.connect(&devices[0].id).await.unwrap();

        let result = adapter.disconnect().await;
        assert!(result.is_ok(), "Should disconnect successfully");

        let is_connected = *adapter.is_connected.lock().await;
        assert!(!is_connected, "Should be marked as disconnected");
    }

    #[tokio::test]
    async fn test_disconnect_without_connection_fails() {
        let adapter = MockAdapter::new();

        let result = adapter.disconnect().await;
        assert!(result.is_err(), "Should fail to disconnect when not connected");
    }

    #[tokio::test]
    async fn test_subscribe_hr_requires_connection() {
        let adapter = MockAdapter::new();

        let result = adapter.subscribe_hr().await;
        assert!(result.is_err(), "Should fail to subscribe when not connected");
    }

    #[tokio::test]
    async fn test_subscribe_hr_streams_data() {
        let adapter = MockAdapter::with_config(MockConfig {
            baseline_bpm: 70,
            update_rate: 10.0, // Faster for testing
            ..Default::default()
        });

        adapter.start_scan().await.unwrap();
        let devices = adapter.get_discovered_devices().await;
        adapter.connect(&devices[0].id).await.unwrap();

        let mut rx = adapter.subscribe_hr().await.unwrap();

        // Receive a few packets
        let packet1 = tokio::time::timeout(Duration::from_secs(1), rx.recv())
            .await
            .expect("Should receive packet within timeout")
            .expect("Should receive valid packet");

        assert!(!packet1.is_empty(), "Packet should not be empty");
        assert_eq!(packet1[0] & 0b10000, 0b10000, "RR-interval flag should be set");
    }

    #[tokio::test]
    async fn test_read_battery() {
        let adapter = MockAdapter::new();

        adapter.start_scan().await.unwrap();
        let devices = adapter.get_discovered_devices().await;
        adapter.connect(&devices[0].id).await.unwrap();

        let battery = adapter.read_battery().await.unwrap();
        assert!(battery <= 100, "Battery level should be valid percentage");
    }

    #[tokio::test]
    async fn test_custom_config() {
        let config = MockConfig {
            baseline_bpm: 120,
            battery_level: 42,
            ..Default::default()
        };

        let adapter = MockAdapter::with_config(config);

        adapter.start_scan().await.unwrap();
        let devices = adapter.get_discovered_devices().await;
        adapter.connect(&devices[0].id).await.unwrap();

        let battery = adapter.read_battery().await.unwrap();
        assert_eq!(battery, 42, "Should use custom battery level");
    }

    #[test]
    fn test_generate_hr_packet_format() {
        let config = MockConfig::default();
        let packet = MockAdapter::generate_hr_packet_static(&config);

        assert!(packet.len() >= 2, "Packet should have at least flags and BPM");

        let flags = packet[0];
        let has_rr = (flags & 0b10000) != 0;

        if has_rr {
            // Should have at least one RR-interval (2 bytes)
            assert!(packet.len() >= 4, "Packet with RR flag should have RR data");
            // RR data length should be even (pairs of bytes)
            assert_eq!((packet.len() - 2) % 2, 0, "RR data should be even length");
        }
    }
}
