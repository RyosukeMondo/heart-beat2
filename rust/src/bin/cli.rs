//! CLI binary for heart rate monitoring and debugging
//!
//! This binary provides a command-line interface for interacting with heart rate
//! monitors via BLE, including device scanning, real-time monitoring, and mock
//! data simulation.

use clap::{Parser, Subcommand};
use heart_beat::adapters::BtleplugAdapter;
use heart_beat::domain::filters::KalmanFilter;
use heart_beat::domain::heart_rate::parse_heart_rate;
use heart_beat::domain::hrv::calculate_rmssd;
use heart_beat::ports::ble_adapter::BleAdapter;
use tracing::{debug, error, info, warn, Level};
use tracing_subscriber::FmtSubscriber;

/// Heart Beat CLI - Heart rate monitoring and debugging tool
#[derive(Parser, Debug)]
#[command(name = "heart-beat-cli")]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Enable verbose debug logging
    #[arg(short, long, global = true)]
    verbose: bool,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Scan for nearby heart rate monitor devices
    Scan,

    /// Connect to a heart rate monitor and stream data
    Connect {
        /// Device ID to connect to (from scan results)
        device_id: String,
    },

    /// Stream mock heart rate data for testing
    Mock,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    // Initialize tracing subscriber based on verbosity level
    let level = if cli.verbose {
        Level::DEBUG
    } else {
        Level::INFO
    };

    let subscriber = FmtSubscriber::builder()
        .with_max_level(level)
        .with_target(false)
        .with_thread_ids(false)
        .with_file(false)
        .finish();

    tracing::subscriber::set_global_default(subscriber)
        .expect("Failed to set tracing subscriber");

    info!("Heart Beat CLI starting");

    match cli.command {
        Commands::Scan => {
            handle_scan().await?;
        }
        Commands::Connect { device_id } => {
            handle_connect(&device_id).await?;
        }
        Commands::Mock => {
            info!("Starting mock data stream...");
            // TODO: Implement mock command
            println!("Mock command not yet implemented");
        }
    }

    Ok(())
}

/// Handle the scan subcommand.
async fn handle_scan() -> anyhow::Result<()> {
    use std::time::Duration;

    info!("Scanning for heart rate monitors...");
    println!("Scanning for heart rate monitors (5 seconds)...\n");

    // Create BLE adapter
    let adapter = BtleplugAdapter::new().await?;

    // Start scanning
    adapter.start_scan().await?;

    // Wait for devices to be discovered
    tokio::time::sleep(Duration::from_secs(5)).await;

    // Stop scanning
    adapter.stop_scan().await?;

    // Get discovered devices
    let devices = adapter.get_discovered_devices().await;

    if devices.is_empty() {
        println!("No devices found.");
        println!("\nMake sure your heart rate monitor is:");
        println!("  • Powered on");
        println!("  • In pairing mode");
        println!("  • Within range (< 10m)");
    } else {
        println!("Found {} device(s):\n", devices.len());

        // Print table header
        println!("{:<40} {:<30} {:>6}", "Device ID", "Name", "RSSI");
        println!("{}", "-".repeat(80));

        // Print each device
        for device in devices {
            let name = device.name.unwrap_or_else(|| "(Unknown)".to_string());
            println!("{:<40} {:<30} {:>6} dBm", device.id, name, device.rssi);
        }

        println!("\nUse 'heart-beat-cli connect <device-id>' to connect to a device.");
    }

    Ok(())
}

/// Handle the connect subcommand.
async fn handle_connect(device_id: &str) -> anyhow::Result<()> {
    use tokio::signal;

    info!("Connecting to device: {}", device_id);
    println!("Connecting to device: {}...\n", device_id);

    // Create BLE adapter
    let adapter = BtleplugAdapter::new().await?;

    // Connect to the device
    adapter.connect(device_id).await?;
    println!("✓ Connected to device");

    // Subscribe to heart rate notifications
    let mut hr_receiver = adapter.subscribe_hr().await?;
    println!("✓ Subscribed to heart rate notifications");

    // Try to read battery level
    match adapter.read_battery().await {
        Ok(battery) => println!("✓ Battery level: {}%\n", battery),
        Err(e) => {
            warn!("Could not read battery level: {}", e);
            println!("⚠ Battery level not available\n");
        }
    }

    // Initialize Kalman filter
    let mut filter = KalmanFilter::default();

    // Print table header
    println!("{:<20} {:>8} {:>12} {:>10}", "Timestamp", "Raw BPM", "Filtered BPM", "RMSSD (ms)");
    println!("{}", "-".repeat(56));

    // Set up Ctrl+C handler
    let ctrl_c = async {
        signal::ctrl_c()
            .await
            .expect("Failed to install Ctrl+C handler");
    };

    // Stream heart rate data
    tokio::select! {
        _ = ctrl_c => {
            info!("Ctrl+C received, disconnecting...");
            println!("\n\nDisconnecting...");
        }
        _ = async {
            while let Some(data) = hr_receiver.recv().await {
                debug!("Received {} bytes of HR data", data.len());

                // Parse the heart rate measurement
                match parse_heart_rate(&data) {
                    Ok(measurement) => {
                        // Filter the BPM value
                        let raw_bpm = measurement.bpm as f64;
                        let filtered_bpm = filter.filter_if_valid(raw_bpm);

                        // Calculate RMSSD if RR-intervals are available
                        let rmssd_str = if !measurement.rr_intervals.is_empty() {
                            match calculate_rmssd(&measurement.rr_intervals) {
                                Some(rmssd) => format!("{:10.2}", rmssd),
                                None => "     -    ".to_string(),
                            }
                        } else {
                            "     -    ".to_string()
                        };

                        // Get current timestamp
                        let timestamp = chrono::Local::now().format("%H:%M:%S%.3f");

                        // Print the data
                        println!(
                            "{:<20} {:>8} {:>12.1} {}",
                            timestamp,
                            measurement.bpm,
                            filtered_bpm,
                            rmssd_str
                        );
                    }
                    Err(e) => {
                        error!("Failed to parse heart rate data: {}", e);
                    }
                }
            }
        } => {
            warn!("Heart rate stream ended unexpectedly");
        }
    }

    // Disconnect from the device
    adapter.disconnect().await?;
    println!("✓ Disconnected");

    Ok(())
}
