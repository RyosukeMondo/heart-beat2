//! Btleplug-based BLE adapter implementation.
//!
//! This module provides a real BLE adapter implementation using the btleplug library.
//! It supports scanning for heart rate monitors, connecting to devices, and subscribing
//! to heart rate measurements on Linux (BlueZ), macOS, and Windows platforms.

use crate::domain::battery::BatteryLevel;
use crate::domain::heart_rate::DiscoveredDevice;
use crate::domain::reconnection::{ConnectionStatus, ReconnectionPolicy};
use crate::ports::ble_adapter::BleAdapter;
use crate::ports::notification::{NotificationEvent, NotificationPort};
use anyhow::{anyhow, Context, Result};
use async_trait::async_trait;
use btleplug::api::{
    Central, CentralEvent, Characteristic, Manager as _, Peripheral as _, ScanFilter,
};
use btleplug::platform::{Adapter, Manager, Peripheral};
use futures::StreamExt;
use std::sync::Arc;
use std::time::SystemTime;
use tokio::sync::{mpsc, Mutex};
use tokio_util::sync::CancellationToken;
use uuid::Uuid;

/// Ensure the current thread is attached to the JVM (Android only).
/// This is required for btleplug JNI calls to work from tokio worker threads.
#[cfg(target_os = "android")]
fn ensure_jvm_attached() -> Result<()> {
    use jni::JavaVM;

    // Get the JavaVM pointer from ndk_context
    let vm_ptr = ndk_context::android_context().vm();
    if vm_ptr.is_null() {
        return Err(anyhow!("AndroidContext VM pointer is null"));
    }

    // Create a JavaVM instance from the pointer
    let jvm = unsafe { JavaVM::from_raw(vm_ptr as *mut jni::sys::JavaVM) }
        .map_err(|e| anyhow!("Failed to create JavaVM from pointer: {:?}", e))?;

    // Check if thread is already attached
    match jvm.get_env() {
        Ok(_) => {
            // Thread already attached
            return Ok(());
        }
        Err(jni::errors::Error::JniCall(jni::errors::JniError::ThreadDetached)) => {
            // Thread not attached, need to attach it
        }
        Err(e) => {
            return Err(anyhow!("Failed to check JVM attachment: {:?}", e));
        }
    }

    // Attach the current thread permanently (it will auto-detach on thread exit)
    match jvm.attach_current_thread_permanently() {
        Ok(_env) => {
            tracing::debug!("Thread attached to JVM successfully");
            Ok(())
        }
        Err(e) => Err(anyhow!("Failed to attach thread to JVM: {:?}", e)),
    }
}

/// No-op on non-Android platforms.
#[cfg(not(target_os = "android"))]
fn ensure_jvm_attached() -> Result<()> {
    Ok(())
}

/// Heart Rate Service UUID (0x180D)
const HR_SERVICE_UUID: Uuid = Uuid::from_u128(0x0000180D_0000_1000_8000_00805F9B34FB);

/// Heart Rate Measurement Characteristic UUID (0x2A37)
const HR_MEASUREMENT_UUID: Uuid = Uuid::from_u128(0x00002A37_0000_1000_8000_00805F9B34FB);

/// Battery Service UUID (0x180F)
const BATTERY_SERVICE_UUID: Uuid = Uuid::from_u128(0x0000180F_0000_1000_8000_00805F9B34FB);

/// Battery Level Characteristic UUID (0x2A19)
const BATTERY_LEVEL_UUID: Uuid = Uuid::from_u128(0x00002A19_0000_1000_8000_00805F9B34FB);

/// Real BLE adapter implementation using btleplug.
///
/// This adapter uses the platform-specific BLE backend (BlueZ on Linux, CoreBluetooth
/// on macOS, WinRT on Windows) to communicate with real BLE heart rate monitors.
pub struct BtleplugAdapter {
    /// The BLE adapter (typically the first/default adapter)
    adapter: Arc<Adapter>,
    /// List of discovered devices during scanning
    discovered_devices: Arc<Mutex<Vec<DiscoveredDevice>>>,
    /// Currently connected peripheral
    connected_peripheral: Arc<Mutex<Option<Peripheral>>>,
}

impl BtleplugAdapter {
    /// Create a new btleplug adapter instance.
    ///
    /// This initializes the BLE manager and gets the first available adapter.
    ///
    /// # Errors
    ///
    /// Returns an error if no BLE adapter is available on the system.
    pub async fn new() -> Result<Self> {
        // Ensure thread is attached to JVM for Android
        ensure_jvm_attached()?;

        let manager = Manager::new()
            .await
            .context("Failed to create BLE manager")?;

        let adapters = manager.adapters().await.context("Failed to get adapters")?;
        let adapter = adapters
            .into_iter()
            .next()
            .ok_or_else(|| anyhow!("No BLE adapter found"))?;

        Ok(Self {
            adapter: Arc::new(adapter),
            discovered_devices: Arc::new(Mutex::new(Vec::new())),
            connected_peripheral: Arc::new(Mutex::new(None)),
        })
    }

    /// Find a peripheral by its device ID.
    async fn find_peripheral(&self, device_id: &str) -> Result<Peripheral> {
        // Ensure thread is attached to JVM for Android
        ensure_jvm_attached()?;

        let peripherals = self.adapter.peripherals().await?;

        for peripheral in peripherals {
            let id = peripheral.id().to_string();
            if id == device_id {
                return Ok(peripheral);
            }
        }

        Err(anyhow!("Device not found: {}", device_id))
    }

    /// Get a characteristic from the connected peripheral.
    async fn get_characteristic(
        peripheral: &Peripheral,
        service_uuid: Uuid,
        char_uuid: Uuid,
    ) -> Result<Characteristic> {
        let services = peripheral
            .services()
            .into_iter()
            .filter(|s| s.uuid == service_uuid)
            .collect::<Vec<_>>();

        let service = services
            .first()
            .ok_or_else(|| anyhow!("Service {} not found", service_uuid))?;

        let characteristic = service
            .characteristics
            .iter()
            .find(|c| c.uuid == char_uuid)
            .ok_or_else(|| anyhow!("Characteristic {} not found", char_uuid))?;

        Ok(characteristic.clone())
    }

    /// Start periodic battery level polling.
    ///
    /// This method spawns a background task that reads the battery level every 60 seconds
    /// and emits `BatteryLevel` updates via the provided channel. It also monitors for
    /// low battery conditions (< 15%) and emits notifications when detected.
    ///
    /// # Arguments
    ///
    /// * `tx` - Channel sender for emitting battery level updates
    /// * `notification_port` - Port for emitting low battery notifications
    ///
    /// # Returns
    ///
    /// A `JoinHandle` that can be used to cancel the polling task.
    ///
    /// # Examples
    ///
    /// ```no_run
    /// # use heart_beat::adapters::btleplug_adapter::BtleplugAdapter;
    /// # use heart_beat::adapters::MockNotificationAdapter;
    /// # use tokio::sync::mpsc;
    /// # use std::sync::Arc;
    /// # async fn example() -> anyhow::Result<()> {
    /// let adapter = BtleplugAdapter::new().await?;
    /// let (tx, mut rx) = mpsc::channel(32);
    /// let notification_port = Arc::new(MockNotificationAdapter::new());
    ///
    /// let handle = adapter.start_battery_polling(tx, notification_port).await?;
    ///
    /// // Later, to stop polling:
    /// handle.abort();
    /// # Ok(())
    /// # }
    /// ```
    pub async fn start_battery_polling(
        &self,
        tx: mpsc::Sender<BatteryLevel>,
        notification_port: Arc<dyn NotificationPort>,
    ) -> Result<tokio::task::JoinHandle<()>> {
        // Clone the connected_peripheral for use in the background task
        let connected_peripheral = self.connected_peripheral.clone();

        // Spawn the polling task
        let handle = tokio::spawn(async move {
            // Create a 60-second interval
            let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(60));

            // Track whether we've already notified about low battery
            // to avoid spamming notifications
            let mut low_battery_notified = false;

            loop {
                // Wait for the next interval tick
                interval.tick().await;

                // Ensure thread is attached to JVM for Android
                if let Err(e) = ensure_jvm_attached() {
                    tracing::error!("Failed to attach JVM during battery polling: {}", e);
                    continue;
                }

                // Get the peripheral
                let guard = connected_peripheral.lock().await;
                let peripheral = match guard.as_ref() {
                    Some(p) => p,
                    None => {
                        tracing::debug!("No device connected, stopping battery polling");
                        break;
                    }
                };

                // Try to get and read the battery level characteristic
                let battery_level = match Self::get_characteristic(
                    peripheral,
                    BATTERY_SERVICE_UUID,
                    BATTERY_LEVEL_UUID,
                )
                .await
                {
                    Ok(battery_char) => match peripheral.read(&battery_char).await {
                        Ok(value) => value.first().copied(),
                        Err(e) => {
                            tracing::warn!("Failed to read battery level: {}", e);
                            None
                        }
                    },
                    Err(e) => {
                        tracing::debug!("Battery service not available: {}", e);
                        None
                    }
                };

                // Create BatteryLevel struct
                let battery = BatteryLevel {
                    level: battery_level,
                    is_charging: false, // BLE Battery Service doesn't provide charging status
                    timestamp: SystemTime::now(),
                };

                // Log the battery level
                if let Some(level) = battery_level {
                    tracing::info!("Battery level: {}%", level);
                } else {
                    tracing::debug!("Battery level not available");
                }

                // Check for low battery and emit notification if needed
                if battery.is_low() {
                    if !low_battery_notified {
                        // Only notify once per low battery condition
                        if let Some(level) = battery.level {
                            tracing::warn!("Low battery detected: {}%", level);
                            if let Err(e) = notification_port
                                .notify(NotificationEvent::BatteryLow { percentage: level })
                                .await
                            {
                                tracing::error!("Failed to send low battery notification: {}", e);
                            }
                            low_battery_notified = true;
                        }
                    }
                } else {
                    // Reset the notification flag when battery is back above threshold
                    low_battery_notified = false;
                }

                // Emit battery level update
                if tx.send(battery).await.is_err() {
                    tracing::debug!("Battery level receiver dropped, stopping polling");
                    break;
                }
            }

            tracing::info!("Battery polling task stopped");
        });

        Ok(handle)
    }

    /// Attempt to reconnect to a device with exponential backoff.
    ///
    /// This method tries to reconnect to a previously connected device, using the
    /// provided reconnection policy to control retry attempts and delays. It emits
    /// `ConnectionStatus` updates throughout the reconnection process and can be
    /// cancelled using the provided `CancellationToken`.
    ///
    /// # Arguments
    ///
    /// * `device_id` - The ID of the device to reconnect to
    /// * `policy` - The reconnection policy defining max attempts and backoff strategy
    /// * `status_tx` - Channel sender for emitting connection status updates
    /// * `cancel_token` - Token for cancelling the reconnection process
    ///
    /// # Returns
    ///
    /// * `Ok(())` if reconnection succeeds
    /// * `Err(...)` if reconnection fails after all attempts or is cancelled
    ///
    /// # Examples
    ///
    /// ```no_run
    /// # use heart_beat::adapters::btleplug_adapter::BtleplugAdapter;
    /// # use heart_beat::domain::reconnection::{ReconnectionPolicy, ConnectionStatus};
    /// # use tokio::sync::mpsc;
    /// # use tokio_util::sync::CancellationToken;
    /// # async fn example() -> anyhow::Result<()> {
    /// let adapter = BtleplugAdapter::new().await?;
    /// let policy = ReconnectionPolicy::default();
    /// let (status_tx, mut status_rx) = mpsc::channel(32);
    /// let cancel_token = CancellationToken::new();
    ///
    /// adapter.reconnect("AA:BB:CC:DD:EE:FF", &policy, status_tx, cancel_token).await?;
    /// # Ok(())
    /// # }
    /// ```
    pub async fn reconnect(
        &self,
        device_id: &str,
        policy: &ReconnectionPolicy,
        status_tx: mpsc::Sender<ConnectionStatus>,
        cancel_token: CancellationToken,
    ) -> Result<()> {
        tracing::info!(
            "Starting reconnection to device {} with policy: max_attempts={}",
            device_id,
            policy.max_attempts
        );

        for attempt in 1..=policy.max_attempts {
            // Check if cancellation was requested
            if cancel_token.is_cancelled() {
                tracing::info!("Reconnection cancelled");
                return Err(anyhow!("Reconnection cancelled"));
            }

            // Emit reconnecting status
            let status = ConnectionStatus::Reconnecting {
                attempt,
                max_attempts: policy.max_attempts,
            };

            if let Err(e) = status_tx.send(status).await {
                tracing::warn!("Failed to send reconnecting status: {}", e);
            }

            tracing::info!(
                "Reconnection attempt {}/{} for device {}",
                attempt,
                policy.max_attempts,
                device_id
            );

            // Calculate and apply delay before attempting connection
            let delay = policy.calculate_delay(attempt);
            tracing::debug!("Waiting {:?} before reconnection attempt", delay);

            // Use tokio::select to make the sleep cancellable
            tokio::select! {
                _ = tokio::time::sleep(delay) => {}
                _ = cancel_token.cancelled() => {
                    tracing::info!("Reconnection cancelled during delay");
                    return Err(anyhow!("Reconnection cancelled"));
                }
            }

            // Attempt to connect
            match self.connect(device_id).await {
                Ok(()) => {
                    tracing::info!(
                        "Reconnection successful on attempt {}/{}",
                        attempt,
                        policy.max_attempts
                    );

                    // Emit connected status
                    let status = ConnectionStatus::Connected {
                        device_id: device_id.to_string(),
                    };

                    if let Err(e) = status_tx.send(status).await {
                        tracing::warn!("Failed to send connected status: {}", e);
                    }

                    return Ok(());
                }
                Err(e) => {
                    tracing::warn!(
                        "Reconnection attempt {}/{} failed: {}",
                        attempt,
                        policy.max_attempts,
                        e
                    );

                    // If this was the last attempt, emit failure status
                    if attempt >= policy.max_attempts {
                        let status = ConnectionStatus::ReconnectFailed {
                            reason: format!("Failed after {} attempts: {}", policy.max_attempts, e),
                        };

                        if let Err(e) = status_tx.send(status).await {
                            tracing::warn!("Failed to send reconnect failed status: {}", e);
                        }

                        return Err(anyhow!(
                            "Reconnection failed after {} attempts: {}",
                            policy.max_attempts,
                            e
                        ));
                    }
                }
            }
        }

        // This shouldn't be reached due to the if statement above, but just in case
        Err(anyhow!(
            "Reconnection failed after {} attempts",
            policy.max_attempts
        ))
    }
}

#[async_trait]
impl BleAdapter for BtleplugAdapter {
    async fn start_scan(&self) -> Result<()> {
        tracing::debug!("BtleplugAdapter::start_scan: Starting");

        // Ensure thread is attached to JVM for Android
        ensure_jvm_attached()?;

        // Clear previous discoveries
        self.discovered_devices.lock().await.clear();

        // Start scanning with a filter for HR service
        let filter = ScanFilter {
            services: vec![HR_SERVICE_UUID],
        };

        tracing::debug!("BtleplugAdapter::start_scan: Calling adapter.start_scan");
        match self.adapter.start_scan(filter).await {
            Ok(()) => {
                tracing::info!("BtleplugAdapter::start_scan: Scan started successfully");
            }
            Err(e) => {
                tracing::error!("BtleplugAdapter::start_scan: btleplug error: {:?}", e);
                return Err(anyhow!("Failed to start BLE scan: {}", e));
            }
        }

        // Set up event handling for discovered devices
        let mut events = self.adapter.events().await?;

        tokio::spawn(async move {
            while let Some(event) = events.next().await {
                if let CentralEvent::DeviceDiscovered(id) = event {
                    // We'll populate device details in get_discovered_devices
                    tracing::debug!("Discovered device: {:?}", id);
                }
            }
        });

        Ok(())
    }

    async fn stop_scan(&self) -> Result<()> {
        // Ensure thread is attached to JVM for Android
        ensure_jvm_attached()?;

        self.adapter
            .stop_scan()
            .await
            .context("Failed to stop BLE scan")?;
        Ok(())
    }

    async fn get_discovered_devices(&self) -> Vec<DiscoveredDevice> {
        // Ensure thread is attached to JVM for Android
        if let Err(e) = ensure_jvm_attached() {
            tracing::error!("Failed to attach JVM: {}", e);
            return Vec::new();
        }

        // Get all peripherals and filter for HR service
        let peripherals = match self.adapter.peripherals().await {
            Ok(p) => p,
            Err(e) => {
                tracing::error!("Failed to get peripherals: {}", e);
                return Vec::new();
            }
        };

        let mut devices = Vec::new();

        for peripheral in peripherals {
            // Get peripheral properties
            let properties = match peripheral.properties().await {
                Ok(Some(props)) => props,
                Ok(None) => continue,
                Err(e) => {
                    tracing::warn!("Failed to get properties: {}", e);
                    continue;
                }
            };

            // Check if device advertises HR service
            let has_hr_service = properties.services.contains(&HR_SERVICE_UUID);

            if has_hr_service {
                devices.push(DiscoveredDevice {
                    id: peripheral.id().to_string(),
                    name: properties.local_name,
                    rssi: properties.rssi.unwrap_or(0),
                });
            }
        }

        // Update cached list
        *self.discovered_devices.lock().await = devices.clone();

        devices
    }

    async fn connect(&self, device_id: &str) -> Result<()> {
        // Ensure thread is attached to JVM for Android
        ensure_jvm_attached()?;

        let peripheral = self.find_peripheral(device_id).await?;

        // Retry connection up to 3 times (Android BLE can fail with GATT error 133)
        let mut last_error = None;
        for attempt in 1..=3 {
            // Re-attach to JVM before each attempt (tokio may switch worker threads)
            if let Err(e) = ensure_jvm_attached() {
                tracing::warn!("Failed to attach to JVM for attempt {}: {}", attempt, e);
            }

            tracing::info!("Connection attempt {} for device {}", attempt, device_id);

            match peripheral.connect().await {
                Ok(()) => {
                    // Re-attach after async operation
                    ensure_jvm_attached()?;

                    tracing::info!("Connected successfully on attempt {}", attempt);

                    // Discover services and characteristics
                    peripheral
                        .discover_services()
                        .await
                        .context("Failed to discover services")?;

                    // Store the connected peripheral
                    *self.connected_peripheral.lock().await = Some(peripheral);

                    return Ok(());
                }
                Err(e) => {
                    tracing::warn!("Connection attempt {} failed: {}", attempt, e);
                    last_error = Some(e);

                    // Wait before retry (increasing backoff)
                    if attempt < 3 {
                        tokio::time::sleep(tokio::time::Duration::from_millis(
                            500 * attempt as u64,
                        ))
                        .await;
                    }
                }
            }
        }

        Err(anyhow!(
            "Failed to connect after 3 attempts: {}",
            last_error.map(|e| e.to_string()).unwrap_or_default()
        ))
    }

    async fn disconnect(&self) -> Result<()> {
        // Ensure thread is attached to JVM for Android
        ensure_jvm_attached()?;

        let mut guard = self.connected_peripheral.lock().await;

        if let Some(peripheral) = guard.take() {
            peripheral
                .disconnect()
                .await
                .context("Failed to disconnect from device")?;
        } else {
            return Err(anyhow!("No device connected"));
        }

        Ok(())
    }

    async fn subscribe_hr(&self) -> Result<mpsc::Receiver<Vec<u8>>> {
        // Ensure thread is attached to JVM for Android
        ensure_jvm_attached()?;

        let guard = self.connected_peripheral.lock().await;
        let peripheral = guard
            .as_ref()
            .ok_or_else(|| anyhow!("No device connected"))?;

        // Get the HR measurement characteristic
        let hr_char =
            Self::get_characteristic(peripheral, HR_SERVICE_UUID, HR_MEASUREMENT_UUID).await?;

        // Subscribe to notifications
        peripheral
            .subscribe(&hr_char)
            .await
            .context("Failed to subscribe to HR notifications")?;

        // Create channel for forwarding notifications
        let (tx, rx) = mpsc::channel(32);

        // Clone peripheral for the notification handler
        let peripheral_clone = peripheral.clone();

        // Spawn task to forward notifications
        tokio::spawn(async move {
            // Attach this worker thread to JVM (Android)
            if let Err(e) = ensure_jvm_attached() {
                tracing::error!("Failed to attach notification thread to JVM: {}", e);
                return;
            }

            let mut notification_stream = match peripheral_clone.notifications().await {
                Ok(stream) => stream,
                Err(e) => {
                    tracing::error!("Failed to get notification stream: {}", e);
                    return;
                }
            };

            while let Some(notification) = notification_stream.next().await {
                // Only forward HR measurement notifications
                if notification.uuid != HR_MEASUREMENT_UUID {
                    continue;
                }

                if tx.send(notification.value).await.is_err() {
                    tracing::debug!("HR notification receiver dropped");
                    break;
                }
            }
        });

        Ok(rx)
    }

    async fn read_battery(&self) -> Result<Option<u8>> {
        // Ensure thread is attached to JVM for Android
        ensure_jvm_attached()?;

        let guard = self.connected_peripheral.lock().await;
        let peripheral = guard
            .as_ref()
            .ok_or_else(|| anyhow!("No device connected"))?;

        // Try to get the battery level characteristic
        // If the service is not found, return None gracefully
        let battery_char =
            match Self::get_characteristic(peripheral, BATTERY_SERVICE_UUID, BATTERY_LEVEL_UUID)
                .await
            {
                Ok(char) => char,
                Err(e) => {
                    tracing::debug!("Battery service not found: {}", e);
                    return Ok(None);
                }
            };

        // Read the characteristic
        let value = peripheral
            .read(&battery_char)
            .await
            .context("Failed to read battery level")?;

        // Battery level is a single byte (0-100)
        let level = value
            .first()
            .copied()
            .ok_or_else(|| anyhow!("Empty battery level response"))?;

        Ok(Some(level))
    }
}
