//! CLI binary for heart rate monitoring and debugging
//!
//! This binary provides a command-line interface for interacting with heart rate
//! monitors via BLE, including device scanning, real-time monitoring, and mock
//! data simulation.

use clap::{Parser, Subcommand};
use heart_beat::adapters::{BtleplugAdapter, MockAdapter};
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
    Mock {
        /// Duration in seconds to run the mock stream (optional, runs indefinitely if not specified)
        #[arg(short, long)]
        duration: Option<u64>,
    },
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
        Commands::Mock { duration } => {
            handle_mock(duration).await?;
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

/// Handle the mock subcommand.
async fn handle_mock(duration: Option<u64>) -> anyhow::Result<()> {
    use tokio::signal;
    use tokio::time::Duration;

    info!("Starting mock data stream...");
    println!("Starting mock heart rate simulation...\n");

    // Create mock adapter
    let adapter = MockAdapter::new();

    // Start scan to populate devices (required before connect)
    adapter.start_scan().await?;

    // Get the first mock device
    let devices = adapter.get_discovered_devices().await;
    if devices.is_empty() {
        return Err(anyhow::anyhow!("No mock devices available"));
    }

    let device_id = &devices[0].id;
    println!("Using mock device: {} ({})",
        devices[0].name.as_ref().unwrap_or(&"Unknown".to_string()),
        device_id
    );

    // Connect to the mock device
    adapter.connect(device_id).await?;
    println!("✓ Connected to mock device");

    // Subscribe to heart rate notifications
    let mut hr_receiver = adapter.subscribe_hr().await?;
    println!("✓ Subscribed to heart rate notifications");

    // Read battery level
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

    // Create duration timeout if specified
    let duration_future = async {
        if let Some(secs) = duration {
            tokio::time::sleep(Duration::from_secs(secs)).await;
            true
        } else {
            // Never complete if no duration specified
            std::future::pending::<bool>().await
        }
    };

    // Stream heart rate data
    tokio::select! {
        _ = ctrl_c => {
            info!("Ctrl+C received, disconnecting...");
            println!("\n\nDisconnecting...");
        }
        _ = duration_future => {
            info!("Duration completed, disconnecting...");
            println!("\n\nDuration completed, disconnecting...");
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
