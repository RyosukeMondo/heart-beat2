//! CLI binary for heart rate monitoring and debugging
//!
//! This binary provides a command-line interface for interacting with heart rate
//! monitors via BLE, including device scanning, real-time monitoring, and mock
//! data simulation.

use clap::{Parser, Subcommand};
use heart_beat::adapters::{BtleplugAdapter, MockAdapter, MockNotificationAdapter};
use heart_beat::domain::filters::KalmanFilter;
use heart_beat::domain::heart_rate::parse_heart_rate;
use heart_beat::domain::hrv::calculate_rmssd;
use heart_beat::domain::training_plan::TrainingPlan;
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
    use comfy_table::{Table, Cell, Color, Attribute, ContentArrangement, presets::UTF8_FULL};
    use indicatif::{ProgressBar, ProgressStyle};

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
            .unwrap()
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
            Cell::new("Name").add_attribute(Attribute::Bold).fg(Color::Cyan),
            Cell::new("Device ID").add_attribute(Attribute::Bold).fg(Color::Cyan),
            Cell::new("RSSI").add_attribute(Attribute::Bold).fg(Color::Cyan),
            Cell::new("Services").add_attribute(Attribute::Bold).fg(Color::Cyan),
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
                Cell::new("HR, Battery"),  // Simplified - actual service detection would need BLE scan
            ]);
        }

        println!("{table}");
        println!("\nUse 'cli devices connect <device-id>' to connect to a device.");
    }

    Ok(())
}

/// Handle the devices connect subcommand.
async fn handle_devices_connect(device_id: &str) -> anyhow::Result<()> {
    use tokio::signal;
    use colored::Colorize;
    use indicatif::{ProgressBar, ProgressStyle};

    info!("Connecting to device: {}", device_id);

    // Show connection progress
    let pb = ProgressBar::new_spinner();
    pb.set_style(
        ProgressStyle::default_spinner()
            .template("{spinner:.green} {msg}")
            .unwrap()
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
    println!("{} Subscribed to heart rate notifications", "✓".green().bold());

    // Try to read battery level
    match adapter.read_battery().await {
        Ok(battery) => {
            let battery_icon = if battery > 80 { "🔋" } else if battery > 20 { "🔋" } else { "🪫" };
            println!("{} Battery level: {}%\n", battery_icon, battery.to_string().cyan().bold());
        }
        Err(e) => {
            warn!("Could not read battery level: {}", e);
            println!("{} Battery level not available\n", "⚠".yellow());
        }
    }

    // Initialize Kalman filter
    let mut filter = KalmanFilter::default();

    // Print table header with colors
    println!("{:<20} {:>8} {:>12} {:>10}",
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

/// Handle the session start subcommand.
async fn handle_session_start(plan_path: &str) -> anyhow::Result<()> {
    use tokio::signal;
    use crossterm::{
        cursor, execute, terminal,
        style::{Color, Print, ResetColor, SetForegroundColor},
    };
    use std::io::{stdout, Write};

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

    // Set up terminal for real-time display
    let mut stdout = stdout();
    execute!(stdout, terminal::Clear(terminal::ClearType::All))?;
    execute!(stdout, cursor::MoveTo(0, 0))?;

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

                // Clear screen and reset cursor
                execute!(stdout, cursor::MoveTo(0, 0)).unwrap();

                // Display header
                execute!(
                    stdout,
                    SetForegroundColor(Color::Cyan),
                    Print(format!("═══ {} ═══\n", plan.name)),
                    ResetColor
                ).unwrap();

                if let Some((phase_idx, elapsed_secs, _phase_duration)) = progress {
                    if phase_idx < plan.phases.len() {
                        let phase = &plan.phases[phase_idx];
                        let remaining_secs = phase.duration_secs.saturating_sub(elapsed_secs);

                        // Display current phase
                        execute!(
                            stdout,
                            Print(format!("\nPhase {}/{}: {}\n", phase_idx + 1, plan.phases.len(), phase.name))
                        ).unwrap();

                        // Display target zone
                        execute!(
                            stdout,
                            SetForegroundColor(Color::Yellow),
                            Print(format!("Target Zone: {:?}\n", phase.target_zone)),
                            ResetColor
                        ).unwrap();

                        // Display time remaining
                        let mins = remaining_secs / 60;
                        let secs = remaining_secs % 60;
                        execute!(
                            stdout,
                            Print(format!("Time Remaining: {:02}:{:02}\n", mins, secs))
                        ).unwrap();

                        // Display elapsed time in phase
                        let elapsed_mins = elapsed_secs / 60;
                        let elapsed_sec = elapsed_secs % 60;
                        execute!(
                            stdout,
                            Print(format!("Elapsed: {:02}:{:02}\n", elapsed_mins, elapsed_sec))
                        ).unwrap();
                    } else {
                        // Session complete
                        execute!(
                            stdout,
                            SetForegroundColor(Color::Green),
                            Print("\n✓ Session Complete!\n"),
                            ResetColor
                        ).unwrap();
                        break;
                    }
                } else {
                    // No active session
                    execute!(
                        stdout,
                        Print("\nSession ended.\n")
                    ).unwrap();
                    break;
                }

                stdout.flush().unwrap();

                // Update every second
                tokio::time::sleep(std::time::Duration::from_secs(1)).await;
            }
        } => {
            info!("Session display loop ended");
        }
    }

    // Stop the session
    executor.stop_session().await?;
    println!("\n\n✓ Session stopped");

    Ok(())
}
