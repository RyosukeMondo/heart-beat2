//! Basic BLE device scanning example.
//!
//! This example demonstrates how to scan for Bluetooth Low Energy heart rate monitors
//! using the Heart Beat library. It uses the mock adapter for demonstration purposes,
//! but can be easily adapted to use real BLE hardware.
//!
//! Run with: cargo run --example basic_scan

use heart_beat::adapters::mock_adapter::{MockAdapter, MockConfig};
use heart_beat::ports::ble_adapter::BleAdapter;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize logging for better visibility
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .init();

    println!("Heart Beat - BLE Device Scanner");
    println!("================================\n");

    // Create a mock BLE adapter
    // For real hardware, you would use: btleplug_adapter::BtleplugAdapter::new().await?
    let config = MockConfig {
        baseline_bpm: 75,
        noise_range: 5,
        spike_probability: 0.0,
        spike_magnitude: 0,
        update_rate: 1.0,
        battery_level: 90,
    };

    let adapter = MockAdapter::with_config(config);

    println!("Starting BLE scan...\n");

    // Start scanning for devices
    adapter.start_scan().await?;

    // Give the scan some time to discover devices
    tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;

    // Get the list of discovered devices
    let devices = adapter.get_discovered_devices().await;

    if devices.is_empty() {
        println!("No devices found. Make sure Bluetooth is enabled.");
        return Ok(());
    }

    println!("Found {} device(s):\n", devices.len());

    // Display discovered devices
    for (i, device) in devices.iter().enumerate() {
        println!("Device {}:", i + 1);
        println!("  ID:   {}", device.id);
        println!("  Name: {}", device.name.as_ref().unwrap_or(&"Unknown".to_string()));
        println!();
    }

    println!("Scan complete!");
    println!("\nTip: Use the device ID to connect to a specific heart rate monitor.");

    Ok(())
}
