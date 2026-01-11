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
    /// Manage BLE device connections
    Devices {
        #[command(subcommand)]
        command: DevicesCmd,
    },

    /// Run training sessions
    Session {
        #[command(subcommand)]
        command: SessionCmd,
    },

    /// Generate simulated HR data
    Mock {
        #[command(subcommand)]
        command: MockCmd,
    },

    /// Manage training plans
    Plan {
        #[command(subcommand)]
        command: PlanCmd,
    },
}

#[derive(Subcommand, Debug)]
enum DevicesCmd {
    /// Scan for nearby heart rate monitor devices
    Scan,

    /// Connect to a device and stream data
    Connect {
        /// Device ID to connect to (from scan results)
        device_id: String,
    },

    /// Show connected device information
    Info,

    /// Disconnect from the current device
    Disconnect,
}

#[derive(Subcommand, Debug)]
enum SessionCmd {
    /// Start a training session with a plan
    Start {
        /// Path to training plan JSON file
        plan_path: String,
    },

    /// Pause the active session
    Pause,

    /// Resume a paused session
    Resume,

    /// Stop the session and show summary
    Stop,
}

#[derive(Subcommand, Debug)]
enum MockCmd {
    /// Generate steady heart rate with noise
    Steady {
        /// Target BPM
        #[arg(long)]
        bpm: u16,
    },

    /// Generate ramping heart rate
    Ramp {
        /// Starting BPM
        #[arg(long)]
        start: u16,

        /// Ending BPM
        #[arg(long)]
        end: u16,

        /// Duration in seconds
        #[arg(long)]
        duration: u32,
    },

    /// Generate interval pattern
    Interval {
        /// Low BPM (rest)
        #[arg(long)]
        low: u16,

        /// High BPM (work)
        #[arg(long)]
        high: u16,

        /// Work period in seconds
        #[arg(long)]
        work_secs: u32,

        /// Rest period in seconds
        #[arg(long)]
        rest_secs: u32,
    },

    /// Simulate packet dropout
    Dropout {
        /// Probability of packet loss (0.0-1.0)
        #[arg(long)]
        probability: f64,
    },
}

#[derive(Subcommand, Debug)]
enum PlanCmd {
    /// List all saved training plans
    List,

    /// Show plan details
    Show {
        /// Plan name
        name: String,
    },

    /// Validate a plan file
    Validate {
        /// Path to plan file
        path: String,
    },

    /// Create a new plan interactively
    Create,
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
        Commands::Devices { command } => match command {
            DevicesCmd::Scan => {
                handle_devices_scan().await?;
            }
            DevicesCmd::Connect { device_id } => {
                handle_devices_connect(&device_id).await?;
            }
            DevicesCmd::Info => {
                eprintln!("Info command not yet implemented");
                std::process::exit(1);
            }
            DevicesCmd::Disconnect => {
                eprintln!("Disconnect command not yet implemented");
                std::process::exit(1);
            }
        },
        Commands::Session { command } => match command {
            SessionCmd::Start { plan_path } => {
                eprintln!("Session start not yet implemented: {}", plan_path);
                std::process::exit(1);
            }
            SessionCmd::Pause => {
                eprintln!("Session pause not yet implemented");
                std::process::exit(1);
            }
            SessionCmd::Resume => {
                eprintln!("Session resume not yet implemented");
                std::process::exit(1);
            }
            SessionCmd::Stop => {
                eprintln!("Session stop not yet implemented");
                std::process::exit(1);
            }
        },
        Commands::Mock { command } => match command {
            MockCmd::Steady { bpm } => {
                handle_mock_steady(bpm).await?;
            }
            MockCmd::Ramp { start, end, duration } => {
                eprintln!("Mock ramp not yet implemented: {} -> {} over {}s", start, end, duration);
                std::process::exit(1);
            }
            MockCmd::Interval { low, high, work_secs, rest_secs } => {
                eprintln!("Mock interval not yet implemented: {}bpm/{}bpm, {}s/{}s", low, high, work_secs, rest_secs);
                std::process::exit(1);
            }
            MockCmd::Dropout { probability } => {
                eprintln!("Mock dropout not yet implemented: {}", probability);
                std::process::exit(1);
            }
        },
        Commands::Plan { command } => match command {
            PlanCmd::List => {
                eprintln!("Plan list not yet implemented");
                std::process::exit(1);
            }
            PlanCmd::Show { name } => {
                eprintln!("Plan show not yet implemented: {}", name);
                std::process::exit(1);
            }
            PlanCmd::Validate { path } => {
                eprintln!("Plan validate not yet implemented: {}", path);
                std::process::exit(1);
            }
            PlanCmd::Create => {
                eprintln!("Plan create not yet implemented");
                std::process::exit(1);
            }
        },
    }

    Ok(())
}

/// Handle the devices scan subcommand.
async fn handle_devices_scan() -> anyhow::Result<()> {
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

/// Handle the devices connect subcommand.
async fn handle_devices_connect(device_id: &str) -> anyhow::Result<()> {
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

/// Handle the mock steady subcommand.
async fn handle_mock_steady(bpm: u16) -> anyhow::Result<()> {
    use tokio::signal;

    info!("Starting mock data stream with steady BPM: {}", bpm);
    println!("Starting mock heart rate simulation (steady {}bpm)...\n", bpm);

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
