//! CLI binary for heart rate monitoring and debugging
//!
//! This binary provides a command-line interface for interacting with heart rate
//! monitors via BLE, including device scanning, real-time monitoring, and mock
//! data simulation.

use clap::{Parser, Subcommand};
use heart_beat::adapters::{BtleplugAdapter, MockAdapter, MockNotificationAdapter};
use heart_beat::domain::filters::KalmanFilter;
use heart_beat::domain::heart_rate::{parse_heart_rate, Zone};
use heart_beat::domain::hrv::calculate_rmssd;
use heart_beat::domain::training_plan::{TrainingPhase, TrainingPlan, TransitionCondition};
use heart_beat::ports::ble_adapter::BleAdapter;
use heart_beat::scheduler::SessionExecutor;
use std::sync::Arc;
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

    tracing::subscriber::set_global_default(subscriber).expect("Failed to set tracing subscriber");

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
                handle_session_start(&plan_path).await?;
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
            MockCmd::Ramp {
                start,
                end,
                duration,
            } => {
                handle_mock_ramp(start, end, duration).await?;
            }
            MockCmd::Interval {
                low,
                high,
                work_secs,
                rest_secs,
            } => {
                handle_mock_interval(low, high, work_secs, rest_secs).await?;
            }
            MockCmd::Dropout { probability } => {
                handle_mock_dropout(probability).await?;
            }
        },
        Commands::Plan { command } => match command {
            PlanCmd::List => {
                handle_plan_list()?;
            }
            PlanCmd::Show { name } => {
                handle_plan_show(&name)?;
            }
            PlanCmd::Validate { path } => {
                handle_plan_validate(&path)?;
            }
            PlanCmd::Create => {
                handle_plan_create()?;
            }
        },
    }

    Ok(())
}

/// Handle the devices scan subcommand.
async fn handle_devices_scan() -> anyhow::Result<()> {
    use comfy_table::{presets::UTF8_FULL, Attribute, Cell, Color, ContentArrangement, Table};
    use indicatif::{ProgressBar, ProgressStyle};
    use std::time::Duration;

    info!("Scanning for heart rate monitors...");

    // Create BLE adapter
    let adapter = BtleplugAdapter::new().await?;

    // Start scanning with progress indicator
    adapter.start_scan().await?;

    // Show scanning progress
    let pb = ProgressBar::new_spinner();
    pb.set_style(
        ProgressStyle::default_spinner()
            .template("{spinner:.green} {msg}")
            .unwrap(),
    );
    pb.set_message("Scanning for heart rate monitors (5 seconds)...");
    pb.enable_steady_tick(std::time::Duration::from_millis(100));

    // Wait for devices to be discovered
    tokio::time::sleep(Duration::from_secs(5)).await;

    // Stop scanning
    adapter.stop_scan().await?;
    pb.finish_and_clear();

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

        // Create table with comfy-table
        let mut table = Table::new();
        table
            .load_preset(UTF8_FULL)
            .set_content_arrangement(ContentArrangement::Dynamic);

        // Add header row
        table.set_header(vec![
            Cell::new("Name")
                .add_attribute(Attribute::Bold)
                .fg(Color::Cyan),
            Cell::new("Device ID")
                .add_attribute(Attribute::Bold)
                .fg(Color::Cyan),
            Cell::new("RSSI")
                .add_attribute(Attribute::Bold)
                .fg(Color::Cyan),
            Cell::new("Services")
                .add_attribute(Attribute::Bold)
                .fg(Color::Cyan),
        ]);

        // Add device rows
        for device in devices {
            let name = device.name.unwrap_or_else(|| "(Unknown)".to_string());
            let rssi_str = format!("{} dBm", device.rssi);

            // Color code RSSI (green for strong, yellow for medium, red for weak)
            let rssi_cell = if device.rssi > -60 {
                Cell::new(&rssi_str).fg(Color::Green)
            } else if device.rssi > -75 {
                Cell::new(&rssi_str).fg(Color::Yellow)
            } else {
                Cell::new(&rssi_str).fg(Color::Red)
            };

            table.add_row(vec![
                Cell::new(&name),
                Cell::new(&device.id),
                rssi_cell,
                Cell::new("HR, Battery"), // Simplified - actual service detection would need BLE scan
            ]);
        }

        println!("{table}");
        println!("\nUse 'cli devices connect <device-id>' to connect to a device.");
    }

    Ok(())
}

/// Handle the devices connect subcommand.
async fn handle_devices_connect(device_id: &str) -> anyhow::Result<()> {
    use colored::Colorize;
    use indicatif::{ProgressBar, ProgressStyle};
    use tokio::signal;

    info!("Connecting to device: {}", device_id);

    // Show connection progress
    let pb = ProgressBar::new_spinner();
    pb.set_style(
        ProgressStyle::default_spinner()
            .template("{spinner:.green} {msg}")
            .unwrap(),
    );
    pb.set_message(format!("Connecting to device: {}", device_id));
    pb.enable_steady_tick(std::time::Duration::from_millis(100));

    // Create BLE adapter
    let adapter = BtleplugAdapter::new().await?;

    // Connect to the device
    adapter.connect(device_id).await?;
    pb.finish_and_clear();
    println!("{} Connected to device", "✓".green().bold());

    // Subscribe to heart rate notifications
    adapter.subscribe_hr().await?;
    let mut hr_receiver = adapter.subscribe_hr().await?;
    println!(
        "{} Subscribed to heart rate notifications",
        "✓".green().bold()
    );

    // Try to read battery level
    match adapter.read_battery().await {
        Ok(battery) => {
            let battery_icon = if battery > 20 { "🔋" } else { "🪫" };
            println!(
                "{} Battery level: {}%\n",
                battery_icon,
                battery.to_string().cyan().bold()
            );
        }
        Err(e) => {
            warn!("Could not read battery level: {}", e);
            println!("{} Battery level not available\n", "⚠".yellow());
        }
    }

    // Initialize Kalman filter
    let mut filter = KalmanFilter::default();

    // Print table header with colors
    println!(
        "{:<20} {:>8} {:>12} {:>10}",
        "Timestamp".cyan().bold(),
        "Raw BPM".cyan().bold(),
        "Filtered BPM".cyan().bold(),
        "RMSSD (ms)".cyan().bold()
    );
    println!("{}", "─".repeat(56).cyan());

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
    println!(
        "Starting mock heart rate simulation (steady {}bpm)...\n",
        bpm
    );

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
    println!(
        "Using mock device: {} ({})",
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
    println!(
        "{:<20} {:>8} {:>12} {:>10}",
        "Timestamp", "Raw BPM", "Filtered BPM", "RMSSD (ms)"
    );
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

/// Handle the session start subcommand.
async fn handle_session_start(plan_path: &str) -> anyhow::Result<()> {
    use session_display::SessionDisplay;
    use tokio::signal;

    info!("Starting training session from plan: {}", plan_path);

    // Load the training plan from JSON file
    let plan_data = std::fs::read_to_string(plan_path)
        .map_err(|e| anyhow::anyhow!("Failed to read plan file '{}': {}", plan_path, e))?;
    let plan: TrainingPlan = serde_json::from_str(&plan_data)
        .map_err(|e| anyhow::anyhow!("Failed to parse plan JSON: {}", e))?;

    // Validate the plan
    plan.validate()
        .map_err(|e| anyhow::anyhow!("Invalid training plan: {}", e))?;

    println!("Training Plan: {}", plan.name);
    println!("Phases: {}", plan.phases.len());
    println!("Max HR: {} BPM\n", plan.max_hr);

    // Create notification adapter
    let notifier = Arc::new(MockNotificationAdapter::new());

    // Create session executor
    let mut executor = SessionExecutor::new(notifier);

    // Start the session
    executor.start_session(plan.clone()).await?;
    println!("✓ Session started\n");

    // Give user a moment to read the message before clearing screen
    tokio::time::sleep(std::time::Duration::from_secs(1)).await;

    // Initialize session display
    let mut display = SessionDisplay::new(&plan);

    // Set up Ctrl+C handler
    let ctrl_c = async {
        signal::ctrl_c()
            .await
            .expect("Failed to install Ctrl+C handler");
    };

    // Main display loop
    tokio::select! {
        _ = ctrl_c => {
            info!("Ctrl+C received, stopping session...");
        }
        _ = async {
            loop {
                // Get current session state
                let progress = executor.get_progress().await;

                if let Some((phase_idx, elapsed_secs, phase_duration)) = progress {
                    if phase_idx < plan.phases.len() {
                        // Update the display with current progress
                        display.update(phase_idx, elapsed_secs, phase_duration, &plan);

                        // Render the display
                        if let Err(e) = display.render() {
                            error!("Failed to render display: {}", e);
                        }
                    } else {
                        // Session complete
                        SessionDisplay::clear().ok();
                        println!("\n✓ Session Complete!\n");
                        break;
                    }
                } else {
                    // No active session
                    SessionDisplay::clear().ok();
                    println!("\nSession ended.\n");
                    break;
                }

                // Update every second
                tokio::time::sleep(std::time::Duration::from_secs(1)).await;
            }
        } => {
            info!("Session display loop ended");
        }
    }

    // Clean up display
    SessionDisplay::clear().ok();

    // Stop the session
    executor.stop_session().await?;
    println!("\n✓ Session stopped");

    Ok(())
}

/// Handle the mock ramp subcommand.
async fn handle_mock_ramp(start: u16, end: u16, duration: u32) -> anyhow::Result<()> {
    use rand::Rng;
    use tokio::signal;

    // Validate inputs
    if !(30..=220).contains(&start) {
        return Err(anyhow::anyhow!("Start BPM must be between 30-220"));
    }
    if !(30..=220).contains(&end) {
        return Err(anyhow::anyhow!("End BPM must be between 30-220"));
    }
    if duration == 0 {
        return Err(anyhow::anyhow!("Duration must be greater than 0"));
    }

    info!(
        "Starting mock ramp: {} -> {} BPM over {} seconds",
        start, end, duration
    );
    println!(
        "Starting mock heart rate ramp ({}bpm -> {}bpm over {}s)...\n",
        start, end, duration
    );

    // Create mock adapter
    let adapter = MockAdapter::new();

    // Start scan to populate devices
    adapter.start_scan().await?;

    // Get the first mock device
    let devices = adapter.get_discovered_devices().await;
    if devices.is_empty() {
        return Err(anyhow::anyhow!("No mock devices available"));
    }

    let device_id = &devices[0].id;
    println!(
        "Using mock device: {} ({})",
        devices[0].name.as_ref().unwrap_or(&"Unknown".to_string()),
        device_id
    );

    // Connect to the mock device
    adapter.connect(device_id).await?;
    println!("✓ Connected to mock device\n");

    // Initialize Kalman filter
    let mut filter = KalmanFilter::default();

    // Print table header
    println!(
        "{:<20} {:>8} {:>12} {:>10}",
        "Timestamp", "Target BPM", "Simulated BPM", "Progress"
    );
    println!("{}", "-".repeat(56));

    // Set up Ctrl+C handler
    let ctrl_c = async {
        signal::ctrl_c()
            .await
            .expect("Failed to install Ctrl+C handler");
    };

    // Calculate delta per second
    let delta = (end as f64 - start as f64) / duration as f64;
    let mut rng = rand::thread_rng();

    // Stream ramping heart rate data
    tokio::select! {
        _ = ctrl_c => {
            info!("Ctrl+C received, disconnecting...");
            println!("\n\nDisconnecting...");
        }
        _ = async {
            for i in 0..duration {
                let target_bpm = start as f64 + (delta * i as f64);

                // Add realistic noise (±3 BPM)
                let noise = rng.gen_range(-3.0..=3.0);
                let simulated_bpm = (target_bpm + noise).clamp(30.0, 220.0);

                // Filter the BPM value
                let filtered_bpm = filter.filter_if_valid(simulated_bpm);

                // Calculate progress
                let progress_pct = ((i + 1) as f64 / duration as f64) * 100.0;

                // Get current timestamp
                let timestamp = chrono::Local::now().format("%H:%M:%S%.3f");

                // Print the data
                println!(
                    "{:<20} {:>8.1} {:>12.1} {:>9.1}%",
                    timestamp,
                    target_bpm,
                    filtered_bpm,
                    progress_pct
                );

                // Wait 1 second
                tokio::time::sleep(std::time::Duration::from_secs(1)).await;
            }

            println!("\n✓ Ramp complete");
        } => {
            info!("Ramp completed");
        }
    }

    // Disconnect from the device
    adapter.disconnect().await?;
    println!("✓ Disconnected");

    Ok(())
}

/// Handle the mock interval subcommand.
async fn handle_mock_interval(
    low: u16,
    high: u16,
    work_secs: u32,
    rest_secs: u32,
) -> anyhow::Result<()> {
    use rand::Rng;
    use tokio::signal;

    // Validate inputs
    if !(30..=220).contains(&low) {
        return Err(anyhow::anyhow!("Low BPM must be between 30-220"));
    }
    if !(30..=220).contains(&high) {
        return Err(anyhow::anyhow!("High BPM must be between 30-220"));
    }
    if low >= high {
        return Err(anyhow::anyhow!("Low BPM must be less than high BPM"));
    }
    if work_secs == 0 || rest_secs == 0 {
        return Err(anyhow::anyhow!(
            "Work and rest periods must be greater than 0"
        ));
    }

    info!(
        "Starting mock interval: {}bpm (rest) / {}bpm (work), {}s/{}s",
        low, high, work_secs, rest_secs
    );
    println!(
        "Starting mock interval training ({}bpm rest/{}bpm work, {}s/{}s)...\n",
        low, high, work_secs, rest_secs
    );

    // Create mock adapter
    let adapter = MockAdapter::new();

    // Start scan to populate devices
    adapter.start_scan().await?;

    // Get the first mock device
    let devices = adapter.get_discovered_devices().await;
    if devices.is_empty() {
        return Err(anyhow::anyhow!("No mock devices available"));
    }

    let device_id = &devices[0].id;
    println!(
        "Using mock device: {} ({})",
        devices[0].name.as_ref().unwrap_or(&"Unknown".to_string()),
        device_id
    );

    // Connect to the mock device
    adapter.connect(device_id).await?;
    println!("✓ Connected to mock device\n");

    // Initialize Kalman filter
    let mut filter = KalmanFilter::default();

    // Print table header
    println!(
        "{:<20} {:>10} {:>8} {:>12} {:>10}",
        "Timestamp", "Phase", "Target", "Simulated", "Remaining"
    );
    println!("{}", "-".repeat(65));

    // Set up Ctrl+C handler
    let ctrl_c = async {
        signal::ctrl_c()
            .await
            .expect("Failed to install Ctrl+C handler");
    };

    let mut rng = rand::thread_rng();
    let mut interval_count = 0;

    // Stream interval heart rate data
    tokio::select! {
        _ = ctrl_c => {
            info!("Ctrl+C received, disconnecting...");
            println!("\n\nDisconnecting...");
        }
        _ = async {
            loop {
                interval_count += 1;

                // Work phase
                println!("\n  --- Interval {} - WORK PHASE ---", interval_count);
                for i in 0..work_secs {
                    let target_bpm = high as f64;

                    // Add realistic noise (±3 BPM)
                    let noise = rng.gen_range(-3.0..=3.0);
                    let simulated_bpm = (target_bpm + noise).clamp(30.0, 220.0);

                    // Filter the BPM value
                    let filtered_bpm = filter.filter_if_valid(simulated_bpm);

                    let remaining = work_secs - i - 1;

                    // Get current timestamp
                    let timestamp = chrono::Local::now().format("%H:%M:%S%.3f");

                    // Print the data
                    println!(
                        "{:<20} {:>10} {:>8} {:>12.1} {:>9}s",
                        timestamp,
                        "WORK",
                        format!("{}bpm", high),
                        filtered_bpm,
                        remaining
                    );

                    // Wait 1 second
                    tokio::time::sleep(std::time::Duration::from_secs(1)).await;
                }

                // Rest phase
                println!("\n  --- Interval {} - REST PHASE ---", interval_count);
                for i in 0..rest_secs {
                    let target_bpm = low as f64;

                    // Add realistic noise (±3 BPM)
                    let noise = rng.gen_range(-3.0..=3.0);
                    let simulated_bpm = (target_bpm + noise).clamp(30.0, 220.0);

                    // Filter the BPM value
                    let filtered_bpm = filter.filter_if_valid(simulated_bpm);

                    let remaining = rest_secs - i - 1;

                    // Get current timestamp
                    let timestamp = chrono::Local::now().format("%H:%M:%S%.3f");

                    // Print the data
                    println!(
                        "{:<20} {:>10} {:>8} {:>12.1} {:>9}s",
                        timestamp,
                        "REST",
                        format!("{}bpm", low),
                        filtered_bpm,
                        remaining
                    );

                    // Wait 1 second
                    tokio::time::sleep(std::time::Duration::from_secs(1)).await;
                }
            }
        } => {
            info!("Interval simulation ended");
        }
    }

    // Disconnect from the device
    adapter.disconnect().await?;
    println!("\n✓ Disconnected");

    Ok(())
}

/// Handle the mock dropout subcommand.
async fn handle_mock_dropout(probability: f64) -> anyhow::Result<()> {
    use rand::Rng;
    use tokio::signal;

    // Validate inputs
    if !(0.0..=1.0).contains(&probability) {
        return Err(anyhow::anyhow!("Probability must be between 0.0 and 1.0"));
    }

    info!(
        "Starting mock dropout simulation with probability: {}",
        probability
    );
    println!(
        "Starting mock heart rate with {}% packet dropout...\n",
        (probability * 100.0)
    );

    // Create mock adapter
    let adapter = MockAdapter::new();

    // Start scan to populate devices
    adapter.start_scan().await?;

    // Get the first mock device
    let devices = adapter.get_discovered_devices().await;
    if devices.is_empty() {
        return Err(anyhow::anyhow!("No mock devices available"));
    }

    let device_id = &devices[0].id;
    println!(
        "Using mock device: {} ({})",
        devices[0].name.as_ref().unwrap_or(&"Unknown".to_string()),
        device_id
    );

    // Connect to the mock device
    adapter.connect(device_id).await?;
    println!("✓ Connected to mock device");

    // Subscribe to heart rate notifications
    let mut hr_receiver = adapter.subscribe_hr().await?;
    println!("✓ Subscribed to heart rate notifications\n");

    // Initialize Kalman filter
    let mut filter = KalmanFilter::default();

    // Print table header
    println!(
        "{:<20} {:>8} {:>12} {:>10} {:>10}",
        "Timestamp", "Raw BPM", "Filtered BPM", "RMSSD (ms)", "Status"
    );
    println!("{}", "-".repeat(70));

    // Set up Ctrl+C handler
    let ctrl_c = async {
        signal::ctrl_c()
            .await
            .expect("Failed to install Ctrl+C handler");
    };

    let mut rng = rand::thread_rng();
    let mut total_packets = 0;
    let mut dropped_packets = 0;

    // Stream heart rate data with dropouts
    tokio::select! {
        _ = ctrl_c => {
            info!("Ctrl+C received, disconnecting...");
            println!("\n\nDisconnecting...");
        }
        _ = async {
            while let Some(data) = hr_receiver.recv().await {
                total_packets += 1;

                // Simulate packet dropout
                let drop_packet = rng.gen::<f64>() < probability;

                if drop_packet {
                    dropped_packets += 1;
                    let timestamp = chrono::Local::now().format("%H:%M:%S%.3f");
                    println!(
                        "{:<20} {:>8} {:>12} {:>10} {:>10}",
                        timestamp,
                        "-",
                        "-",
                        "-",
                        "DROPPED"
                    );
                    continue;
                }

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
                            "{:<20} {:>8} {:>12.1} {} {:>10}",
                            timestamp,
                            measurement.bpm,
                            filtered_bpm,
                            rmssd_str,
                            "OK"
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

    // Print statistics
    let actual_dropout_rate = if total_packets > 0 {
        (dropped_packets as f64 / total_packets as f64) * 100.0
    } else {
        0.0
    };

    println!("\n✓ Disconnected");
    println!("\nDropout Statistics:");
    println!("  Total packets: {}", total_packets);
    println!("  Dropped packets: {}", dropped_packets);
    println!("  Actual dropout rate: {:.1}%", actual_dropout_rate);

    Ok(())
}

/// Handle the plan list subcommand.
fn handle_plan_list() -> anyhow::Result<()> {
    use comfy_table::{presets::UTF8_FULL, Attribute, Cell, Color, ContentArrangement, Table};
    use std::fs;

    info!("Listing training plans");

    // Get plans directory
    let home = dirs::home_dir().ok_or_else(|| anyhow::anyhow!("Could not find home directory"))?;
    let plans_dir = home.join(".heart-beat").join("plans");

    // Create directory if it doesn't exist
    if !plans_dir.exists() {
        fs::create_dir_all(&plans_dir)?;
        println!("No training plans found.");
        println!("\nPlans directory: {}", plans_dir.display());
        println!("Use 'cli plan create' to create a new plan.");
        return Ok(());
    }

    // Read all .json files from the plans directory
    let mut plans: Vec<(String, TrainingPlan)> = Vec::new();

    for entry in fs::read_dir(&plans_dir)? {
        let entry = entry?;
        let path = entry.path();

        if path.extension().and_then(|s| s.to_str()) == Some("json") {
            match fs::read_to_string(&path) {
                Ok(content) => match serde_json::from_str::<TrainingPlan>(&content) {
                    Ok(plan) => {
                        let filename = path
                            .file_stem()
                            .and_then(|s| s.to_str())
                            .unwrap_or("unknown")
                            .to_string();
                        plans.push((filename, plan));
                    }
                    Err(e) => {
                        warn!("Failed to parse plan {}: {}", path.display(), e);
                    }
                },
                Err(e) => {
                    warn!("Failed to read plan {}: {}", path.display(), e);
                }
            }
        }
    }

    if plans.is_empty() {
        println!("No training plans found.");
        println!("\nPlans directory: {}", plans_dir.display());
        println!("Use 'cli plan create' to create a new plan.");
        return Ok(());
    }

    println!("Found {} training plan(s):\n", plans.len());

    // Create table
    let mut table = Table::new();
    table
        .load_preset(UTF8_FULL)
        .set_content_arrangement(ContentArrangement::Dynamic);

    // Add header row
    table.set_header(vec![
        Cell::new("Plan Name")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
        Cell::new("File")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
        Cell::new("Phases")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
        Cell::new("Duration")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
        Cell::new("Max HR")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
    ]);

    // Add plan rows
    for (filename, plan) in plans {
        let total_secs: u32 = plan.phases.iter().map(|p| p.duration_secs).sum();
        let duration_mins = total_secs / 60;
        let duration_str = if duration_mins < 60 {
            format!("{}m", duration_mins)
        } else {
            let hours = duration_mins / 60;
            let mins = duration_mins % 60;
            format!("{}h {}m", hours, mins)
        };

        table.add_row(vec![
            Cell::new(&plan.name),
            Cell::new(&filename),
            Cell::new(plan.phases.len()),
            Cell::new(&duration_str),
            Cell::new(format!("{} BPM", plan.max_hr)),
        ]);
    }

    println!("{table}");
    println!("\nUse 'cli plan show <name>' to view plan details.");
    println!("Plans directory: {}", plans_dir.display());

    Ok(())
}

/// Handle the plan show subcommand.
fn handle_plan_show(name: &str) -> anyhow::Result<()> {
    use comfy_table::{presets::UTF8_FULL, Attribute, Cell, Color, ContentArrangement, Table};
    use std::fs;

    info!("Showing training plan: {}", name);

    // Get plans directory
    let home = dirs::home_dir().ok_or_else(|| anyhow::anyhow!("Could not find home directory"))?;
    let plans_dir = home.join(".heart-beat").join("plans");

    // Build path to plan file
    let plan_path = plans_dir.join(format!("{}.json", name));

    if !plan_path.exists() {
        return Err(anyhow::anyhow!(
            "Plan '{}' not found. Run 'cli plan list' to see available plans.",
            name
        ));
    }

    // Load the plan
    let content = fs::read_to_string(&plan_path)?;
    let plan: TrainingPlan = serde_json::from_str(&content)?;

    // Display plan header
    println!("\n{}", "═".repeat(60));
    println!("Plan: {}", plan.name);
    println!("{}", "═".repeat(60));
    println!("Max HR: {} BPM", plan.max_hr);
    println!("Created: {}", plan.created_at.format("%Y-%m-%d %H:%M:%S"));
    println!("Phases: {}", plan.phases.len());

    let total_secs: u32 = plan.phases.iter().map(|p| p.duration_secs).sum();
    let duration_mins = total_secs / 60;
    println!(
        "Total Duration: {}m ({}h {}m)",
        duration_mins,
        duration_mins / 60,
        duration_mins % 60
    );
    println!();

    // Create phases table
    let mut table = Table::new();
    table
        .load_preset(UTF8_FULL)
        .set_content_arrangement(ContentArrangement::Dynamic);

    // Add header row
    table.set_header(vec![
        Cell::new("#")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
        Cell::new("Phase Name")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
        Cell::new("Target Zone")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
        Cell::new("Duration")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
        Cell::new("Transition")
            .add_attribute(Attribute::Bold)
            .fg(Color::Cyan),
    ]);

    // Add phase rows
    for (idx, phase) in plan.phases.iter().enumerate() {
        let duration_mins = phase.duration_secs / 60;
        let duration_secs = phase.duration_secs % 60;
        let duration_str = if duration_secs == 0 {
            format!("{}m", duration_mins)
        } else {
            format!("{}m {}s", duration_mins, duration_secs)
        };

        // Color code the zone
        let zone_str = format!("{:?}", phase.target_zone);
        let zone_cell = match phase.target_zone {
            Zone::Zone1 => Cell::new(&zone_str).fg(Color::Blue),
            Zone::Zone2 => Cell::new(&zone_str).fg(Color::Green),
            Zone::Zone3 => Cell::new(&zone_str).fg(Color::Yellow),
            Zone::Zone4 => Cell::new(&zone_str).fg(Color::DarkYellow),
            Zone::Zone5 => Cell::new(&zone_str).fg(Color::Red),
        };

        let transition_str = match &phase.transition {
            TransitionCondition::TimeElapsed => "Time".to_string(),
            TransitionCondition::HeartRateReached {
                target_bpm,
                hold_secs,
            } => {
                format!("HR {}bpm ({}s)", target_bpm, hold_secs)
            }
        };

        table.add_row(vec![
            Cell::new(idx + 1),
            Cell::new(&phase.name),
            zone_cell,
            Cell::new(&duration_str),
            Cell::new(&transition_str),
        ]);
    }

    println!("{table}");
    println!(
        "\nUse 'cli session start {}' to run this plan.",
        plan_path.display()
    );

    Ok(())
}

/// Handle the plan validate subcommand.
fn handle_plan_validate(path: &str) -> anyhow::Result<()> {
    use colored::Colorize;
    use std::fs;

    info!("Validating training plan: {}", path);

    // Read the plan file
    let content = fs::read_to_string(path)
        .map_err(|e| anyhow::anyhow!("Failed to read plan file '{}': {}", path, e))?;

    // Parse the JSON
    let plan: TrainingPlan = serde_json::from_str(&content)
        .map_err(|e| anyhow::anyhow!("Failed to parse plan JSON: {}", e))?;

    println!("Validating plan: {}", plan.name);
    println!("File: {}\n", path);

    // Validate the plan
    match plan.validate() {
        Ok(()) => {
            println!("{} Plan is valid!", "✓".green().bold());
            println!("\nPlan Summary:");
            println!("  Name: {}", plan.name);
            println!("  Max HR: {} BPM", plan.max_hr);
            println!("  Phases: {}", plan.phases.len());

            let total_secs: u32 = plan.phases.iter().map(|p| p.duration_secs).sum();
            let duration_mins = total_secs / 60;
            println!(
                "  Total Duration: {}m ({}h {}m)",
                duration_mins,
                duration_mins / 60,
                duration_mins % 60
            );

            Ok(())
        }
        Err(e) => {
            println!("{} Plan validation failed!", "✗".red().bold());
            println!("\n{} {}", "Error:".red().bold(), e);
            Err(e)
        }
    }
}

/// Handle the plan create subcommand.
fn handle_plan_create() -> anyhow::Result<()> {
    use colored::Colorize;
    use dialoguer::{Confirm, Input, Select};
    use std::fs;

    info!("Creating new training plan");

    println!("{}", "═".repeat(60));
    println!("Create New Training Plan");
    println!("{}\n", "═".repeat(60));

    // Get plan name
    let plan_name: String = Input::new().with_prompt("Plan name").interact_text()?;

    // Get max HR
    let max_hr: u16 = Input::new()
        .with_prompt("Maximum heart rate (BPM)")
        .default(180)
        .validate_with(|input: &u16| -> Result<(), &str> {
            if *input < 100 || *input > 220 {
                Err("Max HR must be between 100-220 BPM")
            } else {
                Ok(())
            }
        })
        .interact_text()?;

    // Build phases
    let mut phases = Vec::new();
    let mut phase_num = 1;

    loop {
        println!("\n{} Phase {}", "─".repeat(20), phase_num);

        // Get phase name
        let phase_name: String = Input::new()
            .with_prompt("Phase name")
            .default(format!("Phase {}", phase_num))
            .interact_text()?;

        // Select target zone
        let zones = vec![
            "Zone 1 (Recovery)",
            "Zone 2 (Endurance)",
            "Zone 3 (Tempo)",
            "Zone 4 (Threshold)",
            "Zone 5 (VO2 Max)",
        ];
        let zone_idx = Select::new()
            .with_prompt("Target zone")
            .items(&zones)
            .default(1)
            .interact()?;

        let target_zone = match zone_idx {
            0 => Zone::Zone1,
            1 => Zone::Zone2,
            2 => Zone::Zone3,
            3 => Zone::Zone4,
            4 => Zone::Zone5,
            _ => Zone::Zone2,
        };

        // Get duration
        let duration_mins: u32 = Input::new()
            .with_prompt("Duration (minutes)")
            .default(10)
            .validate_with(|input: &u32| -> Result<(), &str> {
                if *input == 0 {
                    Err("Duration must be greater than 0")
                } else if *input > 240 {
                    Err("Duration must be less than 240 minutes")
                } else {
                    Ok(())
                }
            })
            .interact_text()?;

        let duration_secs = duration_mins * 60;

        // Select transition condition
        let transitions = vec!["Time Elapsed", "Heart Rate Reached"];
        let transition_idx = Select::new()
            .with_prompt("Transition type")
            .items(&transitions)
            .default(0)
            .interact()?;

        let transition = if transition_idx == 0 {
            TransitionCondition::TimeElapsed
        } else {
            let target_bpm: u16 = Input::new()
                .with_prompt("Target BPM")
                .default(140)
                .validate_with(|input: &u16| -> Result<(), &str> {
                    if *input < 30 || *input > 220 {
                        Err("Target BPM must be between 30-220")
                    } else {
                        Ok(())
                    }
                })
                .interact_text()?;

            let hold_secs: u32 = Input::new()
                .with_prompt("Hold duration (seconds)")
                .default(10)
                .validate_with(|input: &u32| -> Result<(), &str> {
                    if *input == 0 {
                        Err("Hold duration must be greater than 0")
                    } else {
                        Ok(())
                    }
                })
                .interact_text()?;

            TransitionCondition::HeartRateReached {
                target_bpm,
                hold_secs,
            }
        };

        // Add phase
        phases.push(TrainingPhase {
            name: phase_name,
            target_zone,
            duration_secs,
            transition,
        });

        // Ask if user wants to add another phase
        let add_another = Confirm::new()
            .with_prompt("Add another phase?")
            .default(false)
            .interact()?;

        if !add_another {
            break;
        }

        phase_num += 1;
    }

    // Create the plan
    let plan = TrainingPlan {
        name: plan_name.clone(),
        phases,
        created_at: chrono::Utc::now(),
        max_hr,
    };

    // Validate the plan
    println!("\nValidating plan...");
    plan.validate()?;
    println!("{} Plan is valid!", "✓".green().bold());

    // Calculate total duration
    let total_secs: u32 = plan.phases.iter().map(|p| p.duration_secs).sum();
    let duration_mins = total_secs / 60;
    println!("\nPlan Summary:");
    println!("  Name: {}", plan.name);
    println!("  Max HR: {} BPM", plan.max_hr);
    println!("  Phases: {}", plan.phases.len());
    println!(
        "  Total Duration: {}m ({}h {}m)",
        duration_mins,
        duration_mins / 60,
        duration_mins % 60
    );

    // Save the plan
    let home = dirs::home_dir().ok_or_else(|| anyhow::anyhow!("Could not find home directory"))?;
    let plans_dir = home.join(".heart-beat").join("plans");
    fs::create_dir_all(&plans_dir)?;

    // Create filename from plan name (sanitize)
    let filename = plan_name
        .to_lowercase()
        .replace(' ', "-")
        .chars()
        .filter(|c| c.is_alphanumeric() || *c == '-')
        .collect::<String>();

    let plan_path = plans_dir.join(format!("{}.json", filename));

    // Serialize to JSON
    let json = serde_json::to_string_pretty(&plan)?;
    fs::write(&plan_path, json)?;

    println!(
        "\n{} Plan saved to: {}",
        "✓".green().bold(),
        plan_path.display()
    );
    println!(
        "\nRun 'cli session start {}' to start this plan.",
        plan_path.display()
    );

    Ok(())
}

/// Session display module for real-time terminal UI during training sessions.
mod session_display {
    use crossterm::{
        cursor, execute,
        style::{Attribute, Color, Print, ResetColor, SetAttribute, SetForegroundColor},
        terminal,
    };
    use heart_beat::domain::heart_rate::Zone;
    use heart_beat::domain::training_plan::TrainingPlan;
    use std::io::{stdout, Result, Write};

    /// Session display state for rendering the training session UI.
    pub struct SessionDisplay {
        plan_name: String,
        current_phase: usize,
        total_phases: usize,
        phase_name: String,
        current_bpm: Option<u16>,
        target_zone: Zone,
        elapsed_secs: u32,
        remaining_secs: u32,
        max_hr: u16,
    }

    impl SessionDisplay {
        /// Create a new session display.
        pub fn new(plan: &TrainingPlan) -> Self {
            Self {
                plan_name: plan.name.clone(),
                current_phase: 0,
                total_phases: plan.phases.len(),
                phase_name: String::new(),
                current_bpm: None,
                target_zone: Zone::Zone2,
                elapsed_secs: 0,
                remaining_secs: 0,
                max_hr: plan.max_hr,
            }
        }

        /// Update the display with current session state.
        pub fn update(
            &mut self,
            phase_idx: usize,
            elapsed: u32,
            phase_duration: u32,
            plan: &TrainingPlan,
        ) {
            if phase_idx < plan.phases.len() {
                let phase = &plan.phases[phase_idx];
                self.current_phase = phase_idx;
                self.phase_name = phase.name.clone();
                self.target_zone = phase.target_zone;
                self.elapsed_secs = elapsed;
                self.remaining_secs = phase_duration.saturating_sub(elapsed);
            }
        }

        /// Update the current heart rate.
        #[allow(dead_code)]
        pub fn update_bpm(&mut self, bpm: u16) {
            self.current_bpm = Some(bpm);
        }

        /// Render the session display to the terminal.
        pub fn render(&self) -> Result<()> {
            let mut stdout = stdout();

            // Clear screen and move to top
            execute!(stdout, terminal::Clear(terminal::ClearType::All))?;
            execute!(stdout, cursor::MoveTo(0, 0))?;

            // Render header with plan name
            self.render_header(&mut stdout)?;

            // Render current phase info
            self.render_phase_info(&mut stdout)?;

            // Render large BPM display
            self.render_bpm(&mut stdout)?;

            // Render zone bar
            self.render_zone_bar(&mut stdout)?;

            // Render progress info
            self.render_progress(&mut stdout)?;

            // Render zone deviation status
            self.render_zone_status(&mut stdout)?;

            stdout.flush()?;
            Ok(())
        }

        fn render_header(&self, stdout: &mut std::io::Stdout) -> Result<()> {
            let header_line = "═".repeat(60);
            execute!(
                stdout,
                SetForegroundColor(Color::Cyan),
                SetAttribute(Attribute::Bold),
                Print(format!("╔{}╗\n", header_line)),
                Print(format!("║{:^60}║\n", self.plan_name)),
                Print(format!(
                    "║ Phase {}/{}: {:54} ║\n",
                    self.current_phase + 1,
                    self.total_phases,
                    self.phase_name
                )),
                Print(format!("╠{}╣\n", header_line)),
                ResetColor
            )?;
            Ok(())
        }

        fn render_phase_info(&self, _stdout: &mut std::io::Stdout) -> Result<()> {
            // Phase info is in the header
            Ok(())
        }

        fn render_bpm(&self, stdout: &mut std::io::Stdout) -> Result<()> {
            execute!(
                stdout,
                Print("║                                                            ║\n")
            )?;

            if let Some(bpm) = self.current_bpm {
                // Display large BPM
                execute!(
                    stdout,
                    Print("║"),
                    SetForegroundColor(self.get_bpm_color(bpm)),
                    SetAttribute(Attribute::Bold),
                    Print(format!("{:^60}", format!("{} BPM", bpm))),
                    ResetColor,
                    Print("║\n")
                )?;
            } else {
                execute!(
                    stdout,
                    Print("║"),
                    SetForegroundColor(Color::Grey),
                    Print(format!("{:^60}", "--- BPM")),
                    ResetColor,
                    Print("║\n")
                )?;
            }

            execute!(
                stdout,
                Print("║                                                            ║\n")
            )?;
            Ok(())
        }

        fn render_zone_bar(&self, stdout: &mut std::io::Stdout) -> Result<()> {
            let bar_width = 40;
            let zone_color = self.get_zone_color();
            let bar = "█".repeat(bar_width);

            execute!(
                stdout,
                Print("║  "),
                SetForegroundColor(zone_color),
                SetAttribute(Attribute::Bold),
                Print(&bar),
                ResetColor,
                Print("  ║\n")
            )?;

            // Show zone label
            execute!(
                stdout,
                Print("║  "),
                SetForegroundColor(zone_color),
                Print(format!("{:^40}", format!("{:?}", self.target_zone))),
                ResetColor,
                Print("  ║\n")
            )?;

            execute!(
                stdout,
                Print("║                                                            ║\n")
            )?;
            Ok(())
        }

        fn render_progress(&self, stdout: &mut std::io::Stdout) -> Result<()> {
            let elapsed_mins = self.elapsed_secs / 60;
            let elapsed_secs = self.elapsed_secs % 60;
            let remaining_mins = self.remaining_secs / 60;
            let remaining_secs = self.remaining_secs % 60;

            execute!(
                stdout,
                Print("║  "),
                SetAttribute(Attribute::Bold),
                Print(format!("Elapsed: {:02}:{:02}", elapsed_mins, elapsed_secs)),
                ResetColor,
                Print("  │  "),
                SetAttribute(Attribute::Bold),
                Print(format!(
                    "Remaining: {:02}:{:02}",
                    remaining_mins, remaining_secs
                )),
                ResetColor,
                Print("  │  "),
                SetForegroundColor(self.get_zone_color()),
                SetAttribute(Attribute::Bold),
                Print(format!("Target: {:?}", self.target_zone)),
                ResetColor,
                Print("  ║\n")
            )?;

            execute!(
                stdout,
                Print("║                                                            ║\n")
            )?;
            Ok(())
        }

        fn render_zone_status(&self, stdout: &mut std::io::Stdout) -> Result<()> {
            if let Some(bpm) = self.current_bpm {
                let zone = self.calculate_current_zone(bpm);
                let status = if zone == self.target_zone {
                    ("✓ IN ZONE", Color::Green)
                } else if zone < self.target_zone {
                    ("↓ BELOW TARGET ZONE", Color::Blue)
                } else {
                    ("↑ ABOVE TARGET ZONE", Color::Red)
                };

                execute!(
                    stdout,
                    Print("║  "),
                    SetForegroundColor(status.1),
                    SetAttribute(Attribute::Bold),
                    Print(format!("{:^56}", status.0)),
                    ResetColor,
                    Print("  ║\n")
                )?;
            } else {
                execute!(
                    stdout,
                    Print("║"),
                    SetForegroundColor(Color::Grey),
                    Print(format!("{:^60}", "Waiting for heart rate data...")),
                    ResetColor,
                    Print("║\n")
                )?;
            }

            let footer_line = "═".repeat(60);
            execute!(
                stdout,
                SetForegroundColor(Color::Cyan),
                Print(format!("╚{}╝\n", footer_line)),
                ResetColor
            )?;

            Ok(())
        }

        fn get_zone_color(&self) -> Color {
            match self.target_zone {
                Zone::Zone1 => Color::Blue,
                Zone::Zone2 => Color::Green,
                Zone::Zone3 => Color::Yellow,
                Zone::Zone4 => Color::DarkYellow,
                Zone::Zone5 => Color::Red,
            }
        }

        fn get_bpm_color(&self, bpm: u16) -> Color {
            let zone = self.calculate_current_zone(bpm);
            if zone == self.target_zone {
                Color::Green
            } else if zone < self.target_zone {
                Color::Blue
            } else {
                Color::Red
            }
        }

        fn calculate_current_zone(&self, bpm: u16) -> Zone {
            use heart_beat::domain::training_plan::calculate_zone;
            match calculate_zone(bpm, self.max_hr) {
                Ok(Some(zone)) => zone,
                _ => Zone::Zone2, // Default fallback
            }
        }

        /// Clear the terminal on exit.
        pub fn clear() -> Result<()> {
            let mut stdout = stdout();
            execute!(stdout, terminal::Clear(terminal::ClearType::All))?;
            execute!(stdout, cursor::MoveTo(0, 0))?;
            stdout.flush()?;
            Ok(())
        }
    }
}
