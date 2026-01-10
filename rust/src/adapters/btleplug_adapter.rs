//! Btleplug-based BLE adapter implementation.
//!
//! This module provides a real BLE adapter implementation using the btleplug library.
//! It supports scanning for heart rate monitors, connecting to devices, and subscribing
//! to heart rate measurements on Linux (BlueZ), macOS, and Windows platforms.

use crate::domain::heart_rate::DiscoveredDevice;
use crate::ports::ble_adapter::BleAdapter;
use anyhow::{anyhow, Context, Result};
use async_trait::async_trait;
use btleplug::api::{
    Central, CentralEvent, Characteristic, Manager as _, Peripheral as _, ScanFilter,
};
use btleplug::platform::{Adapter, Manager, Peripheral};
use futures::StreamExt;
use std::sync::Arc;
use tokio::sync::{mpsc, Mutex};
use uuid::Uuid;

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
}

#[async_trait]
impl BleAdapter for BtleplugAdapter {
    async fn start_scan(&self) -> Result<()> {
        // Clear previous discoveries
        self.discovered_devices.lock().await.clear();

        // Start scanning with a filter for HR service
        let filter = ScanFilter {
            services: vec![HR_SERVICE_UUID],
        };

        self.adapter
            .start_scan(filter)
            .await
            .context("Failed to start BLE scan")?;

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
        self.adapter
            .stop_scan()
            .await
            .context("Failed to stop BLE scan")?;
        Ok(())
    }

    async fn get_discovered_devices(&self) -> Vec<DiscoveredDevice> {
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
            let has_hr_service = properties
                .services
                .iter()
                .any(|uuid| *uuid == HR_SERVICE_UUID);

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
        let peripheral = self.find_peripheral(device_id).await?;

        peripheral
            .connect()
            .await
            .context("Failed to connect to device")?;

        // Discover services and characteristics
        peripheral
            .discover_services()
            .await
            .context("Failed to discover services")?;

        // Store the connected peripheral
        *self.connected_peripheral.lock().await = Some(peripheral);

        Ok(())
    }

    async fn disconnect(&self) -> Result<()> {
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
            let mut notification_stream = match peripheral_clone.notifications().await {
                Ok(stream) => stream,
                Err(e) => {
                    tracing::error!("Failed to get notification stream: {}", e);
                    return;
                }
            };

            while let Some(notification) = notification_stream.next().await {
                if notification.uuid == HR_MEASUREMENT_UUID {
                    if tx.send(notification.value).await.is_err() {
                        tracing::debug!("HR notification receiver dropped");
                        break;
                    }
                }
            }
        });

        Ok(rx)
    }

    async fn read_battery(&self) -> Result<u8> {
        let guard = self.connected_peripheral.lock().await;
        let peripheral = guard
            .as_ref()
            .ok_or_else(|| anyhow!("No device connected"))?;

        // Get the battery level characteristic
        let battery_char =
            Self::get_characteristic(peripheral, BATTERY_SERVICE_UUID, BATTERY_LEVEL_UUID).await?;

        // Read the characteristic
        let value = peripheral
            .read(&battery_char)
            .await
            .context("Failed to read battery level")?;

        // Battery level is a single byte (0-100)
        value
            .first()
            .copied()
            .ok_or_else(|| anyhow!("Empty battery level response"))
    }
}
