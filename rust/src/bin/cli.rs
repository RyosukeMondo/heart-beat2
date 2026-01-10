//! CLI binary for heart rate monitoring and debugging
//!
//! This binary provides a command-line interface for interacting with heart rate
//! monitors via BLE, including device scanning, real-time monitoring, and mock
//! data simulation.

use clap::{Parser, Subcommand};
use tracing::{info, Level};
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

fn main() -> anyhow::Result<()> {
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
            info!("Scanning for devices...");
            // TODO: Implement scan command
            println!("Scan command not yet implemented");
        }
        Commands::Connect { device_id } => {
            info!("Connecting to device: {}", device_id);
            // TODO: Implement connect command
            println!("Connect command not yet implemented for device: {}", device_id);
        }
        Commands::Mock => {
            info!("Starting mock data stream...");
            // TODO: Implement mock command
            println!("Mock command not yet implemented");
        }
    }

    Ok(())
}
