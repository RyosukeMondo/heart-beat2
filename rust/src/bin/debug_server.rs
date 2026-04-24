//! Debug server binary for Heart Beat.
//!
//! Provides a REST API and WebSocket streaming interface to all heart-beat
//! library features. Useful for testing without the Flutter GUI.

use clap::Parser;
use heart_beat::api;
use heart_beat::debug_http;
use heart_beat::logging;
use std::net::SocketAddr;

/// Heart Beat Debug Server — REST + WebSocket interface for testing
#[derive(Parser, Debug)]
#[command(name = "heart-beat-debug-server")]
struct Args {
    /// HTTP port to listen on
    #[arg(short, long, default_value_t = 8888)]
    port: u16,

    /// Data directory (default: ~/.heart-beat)
    #[arg(long)]
    data_dir: Option<String>,

    /// Start mock BLE mode automatically
    #[arg(long)]
    r#mock: bool,

    /// Enable verbose (debug-level) logging
    #[arg(short, long)]
    verbose: bool,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args = Args::parse();

    // Initialize START_TIME before anything else
    heart_beat::debug_http::START_TIME.get_or_init(|| std::time::Instant::now());

    // Resolve data dir
    let data_dir = if let Some(ref p) = args.data_dir {
        std::path::PathBuf::from(p)
    } else {
        dirs::home_dir()
            .expect("Cannot determine home directory")
            .join(".heart-beat")
    };
    std::fs::create_dir_all(&data_dir)?;

    // Set up logging (file + stderr + broadcast)
    let log_dir = data_dir.join("logs");
    std::fs::create_dir_all(&log_dir)?;
    logging::init_server_logging(Some(&log_dir), args.verbose);

    // Tell the library where to store data
    api::set_data_dir(data_dir.to_string_lossy().to_string())?;

    tracing::info!("Debug server starting on port {}", args.port);

    // Start mock mode if requested
    if args.mock {
        tracing::info!("Starting mock BLE mode");
        api::start_mock_mode().await?;
    }

    let app = debug_http::build_router();
    let addr = SocketAddr::from(([0, 0, 0, 0], args.port));
    tracing::info!("Listening on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}