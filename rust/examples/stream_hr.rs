//! Heart rate streaming example.
//!
//! This example demonstrates how to connect to a heart rate monitor and stream
//! real-time heart rate data. It shows the complete workflow:
//! 1. Scan for devices
//! 2. Connect to a device
//! 3. Subscribe to HR notifications
//! 4. Parse and filter incoming data
//! 5. Display live heart rate readings
//!
//! Run with: cargo run --example stream_hr

use heart_beat::adapters::mock_adapter::{MockAdapter, MockConfig};
use heart_beat::domain::filters::KalmanFilter;
use heart_beat::domain::heart_rate::{parse_heart_rate, FilteredHeartRate};
use heart_beat::domain::hrv::calculate_rmssd;
use heart_beat::ports::ble_adapter::BleAdapter;
use tokio::time::{timeout, Duration};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize logging
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .init();

    println!("Heart Beat - Heart Rate Streaming");
    println!("==================================\n");

    // Create mock adapter with realistic settings
    let config = MockConfig {
        baseline_bpm: 75,
        noise_range: 5,
        spike_probability: 0.05,
        spike_magnitude: 10,
        update_rate: 1.0, // 1 Hz (once per second)
        battery_level: 85,
    };

    let adapter = MockAdapter::with_config(config);

    // Step 1: Scan for devices
    println!("Scanning for devices...");
    adapter.start_scan().await?;
    tokio::time::sleep(Duration::from_secs(1)).await;

    let devices = adapter.get_discovered_devices().await;
    if devices.is_empty() {
        println!("No devices found!");
        return Ok(());
    }

    println!(
        "Found device: {}\n",
        devices[0].name.as_ref().unwrap_or(&"Unknown".to_string())
    );

    // Step 2: Connect to the first device
    println!("Connecting to device...");
    let device_id = &devices[0].id;
    adapter.connect(device_id).await?;
    println!("Connected!\n");

    // Step 3: Subscribe to heart rate notifications
    println!("Subscribing to heart rate notifications...");
    let mut hr_receiver = adapter.subscribe_hr().await?;
    println!("Streaming heart rate data (Ctrl+C to stop)...\n");

    // Initialize Kalman filter for smoothing BPM readings
    let mut kalman_filter = KalmanFilter::default();

    // Step 4: Stream and process heart rate data
    let mut sample_count = 0;
    let max_samples = 20; // Stream for 20 samples then exit

    while sample_count < max_samples {
        // Receive HR packet with timeout
        match timeout(Duration::from_secs(3), hr_receiver.recv()).await {
            Ok(Some(packet)) => {
                // Parse the raw BLE packet
                match parse_heart_rate(&packet) {
                    Ok(measurement) => {
                        // Apply Kalman filter to smooth the BPM reading
                        let raw_bpm = measurement.bpm;
                        let filtered_value = kalman_filter.update(raw_bpm as f64);
                        let filtered_bpm = filtered_value.round() as u16;

                        // Calculate HRV if RR-intervals are available
                        let rmssd = if measurement.rr_intervals.len() >= 2 {
                            calculate_rmssd(&measurement.rr_intervals)
                        } else {
                            None
                        };

                        // Package into FilteredHeartRate output
                        let output = FilteredHeartRate {
                            raw_bpm,
                            filtered_bpm,
                            rmssd,
                            battery_level: Some(85),
                            timestamp: std::time::SystemTime::now()
                                .duration_since(std::time::UNIX_EPOCH)
                                .unwrap()
                                .as_millis() as u64,
                        };

                        // Display the results
                        sample_count += 1;
                        print!("[{}] ", sample_count);
                        print!("HR: {} BPM ", output.filtered_bpm);
                        print!("(raw: {}) ", output.raw_bpm);

                        if let Some(hrv) = output.rmssd {
                            print!("HRV: {:.1} ms ", hrv);
                        }

                        println!("Battery: {}%", output.battery_level.unwrap_or(0));
                    }
                    Err(e) => {
                        eprintln!("Error parsing HR packet: {}", e);
                    }
                }
            }
            Ok(None) => {
                println!("Connection closed");
                break;
            }
            Err(_) => {
                println!("Timeout waiting for data");
                break;
            }
        }
    }

    // Step 5: Clean disconnect
    println!("\nDisconnecting...");
    adapter.disconnect().await?;
    println!("Done!");

    Ok(())
}
