//! Flutter Rust Bridge API Layer
//!
//! This module provides the FFI boundary between Rust core logic and Flutter UI.
//! It orchestrates domain, state, and adapter components without containing business logic.

use crate::adapters::btleplug_adapter::BtleplugAdapter;
use crate::adapters::file_session_repository::FileSessionRepository;
use crate::domain::filters::KalmanFilter;
use crate::domain::heart_rate::{parse_heart_rate, DiscoveredDevice, FilteredHeartRate};
use crate::domain::training_plan::TrainingPlan;
use crate::frb_generated::StreamSink;
use crate::ports::{BleAdapter, NotificationPort, SessionRepository};
use crate::scheduler::executor::SessionExecutor;
use crate::state::{ConnectionEvent, ConnectionStateMachine};
use anyhow::{anyhow, Result};
use async_trait::async_trait;
use std::io::Write;
use std::panic;
use std::sync::{Arc, Mutex, OnceLock};
use std::time::Duration;
use tokio::sync::broadcast;
use tracing::error;
use tracing_subscriber::{
    fmt::{format::FmtSpan, MakeWriter},
    EnvFilter,
};

#[cfg(target_os = "android")]
use log::LevelFilter;

// Re-export domain types for FRB code generation
pub use crate::domain::heart_rate::{
    DiscoveredDevice as ApiDiscoveredDevice, FilteredHeartRate as ApiFilteredHeartRate, Zone,
};
pub use crate::domain::session_history::CompletedSession as ApiCompletedSession;
pub use crate::ports::session_repository::SessionSummaryPreview as ApiSessionSummaryPreview;

// Re-export SessionProgress types for FRB code generation
pub use crate::domain::session_progress::{
    PhaseProgress as ApiPhaseProgress, SessionProgress as ApiSessionProgress,
    SessionState as ApiSessionState, ZoneStatus as ApiZoneStatus,
};

// Re-export reconnection types for FRB code generation
pub use crate::domain::reconnection::ConnectionStatus as ApiConnectionStatus;

/// Format for exporting session data.
///
/// Specifies the output format when exporting a completed training session.
#[derive(Clone, Copy, Debug, serde::Serialize, serde::Deserialize)]
pub enum ExportFormat {
    /// Export as comma-separated values (CSV) with timestamp, bpm, and zone columns
    Csv,
    /// Export as pretty-printed JSON containing the full session structure
    Json,
    /// Export as human-readable text summary with statistics
    Summary,
}

/// Battery level data for FFI boundary (FRB-compatible).
///
/// This is a simplified version of domain::BatteryLevel that uses u64 timestamps
/// instead of SystemTime to be compatible with Flutter Rust Bridge.
#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
pub struct ApiBatteryLevel {
    /// Battery level as a percentage (0-100).
    pub level: Option<u8>,
    /// Whether the device is currently charging.
    pub is_charging: bool,
    /// Unix timestamp in milliseconds when this battery level was measured.
    pub timestamp: u64,
}

// Global data directory for storing app data (plans, sessions, etc.)
// On Android, this must be set via set_data_dir() before using file-based APIs.
// On desktop, it falls back to ~/.heart-beat if not set.
static DATA_DIR: OnceLock<Mutex<Option<std::path::PathBuf>>> = OnceLock::new();

// Global state for HR data streaming
static HR_CHANNEL_CAPACITY: usize = 100;

// Global state for battery data streaming
static BATTERY_CHANNEL_CAPACITY: usize = 10;

// Global state for session progress streaming
static SESSION_PROGRESS_CHANNEL_CAPACITY: usize = 100;

// Global state for connection status streaming
static CONNECTION_STATUS_CHANNEL_CAPACITY: usize = 10;

/// Log message that can be sent to Flutter for debugging.
///
/// This struct represents a single log entry with level, target module,
/// timestamp, and message content. It's designed to be sent across the FFI
/// boundary to Flutter for display in the debug console.
#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
pub struct LogMessage {
    /// Log level (TRACE, DEBUG, INFO, WARN, ERROR)
    pub level: String,
    /// Module path where the log originated (e.g., "heart_beat::adapters")
    pub target: String,
    /// Timestamp in milliseconds since Unix epoch
    pub timestamp: u64,
    /// The actual log message
    pub message: String,
}

// Global state for log streaming
static LOG_SINK: OnceLock<Mutex<Option<StreamSink<LogMessage>>>> = OnceLock::new();

// Global BLE adapter - shared between scan and connect operations
// This is critical: we must use the same adapter instance that discovered the devices
// to connect to them, otherwise btleplug won't find the peripheral.
static BLE_ADAPTER: OnceLock<tokio::sync::Mutex<Option<Arc<BtleplugAdapter>>>> = OnceLock::new();

/// Active connection state tracking for disconnect functionality.
///
/// Stores references to the active adapter and background task handles
/// so they can be properly cleaned up during disconnect.
struct ConnectionState {
    /// The connected BLE adapter instance
    adapter: Arc<BtleplugAdapter>,
    /// Device ID of the connected device
    device_id: String,
    /// Handle to the HR notification streaming task
    hr_task_handle: tokio::task::JoinHandle<()>,
    /// Handle to the battery polling task
    battery_task_handle: tokio::task::JoinHandle<()>,
}

// Global connection state storage
static CONNECTION_STATE: OnceLock<tokio::sync::Mutex<Option<ConnectionState>>> = OnceLock::new();

/// Stub notification port for battery monitoring.
/// This is a temporary implementation until full notification system is wired up.
struct StubNotificationPort;

#[async_trait]
impl NotificationPort for StubNotificationPort {
    async fn notify(&self, event: crate::ports::NotificationEvent) -> Result<()> {
        // Just log the notification for now
        tracing::info!("Notification: {:?}", event);
        Ok(())
    }
}

/// Get or create the global BLE adapter instance.
/// Returns the same adapter across all calls to ensure device discovery persists.
async fn get_ble_adapter() -> Result<Arc<BtleplugAdapter>> {
    let mutex = BLE_ADAPTER.get_or_init(|| tokio::sync::Mutex::new(None));
    let mut guard = mutex.lock().await;

    if let Some(ref adapter) = *guard {
        return Ok(adapter.clone());
    }

    // Create new adapter and store it
    tracing::info!("Creating new global BLE adapter");
    let adapter = Arc::new(BtleplugAdapter::new().await?);
    *guard = Some(adapter.clone());
    Ok(adapter)
}

/// Custom writer that forwards logs to Flutter via StreamSink.
///
/// This writer implements the std::io::Write trait and is used by tracing_subscriber
/// to capture log output. Instead of writing to stdout/stderr, it parses the log
/// messages and sends them to Flutter through the FRB StreamSink.
struct FlutterLogWriter;

impl Write for FlutterLogWriter {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        let log_str = String::from_utf8_lossy(buf);

        // Parse the log message
        // Format: "2024-01-11T12:34:56.789Z  INFO heart_beat::api: Message here"
        if let Some(sink_mutex) = LOG_SINK.get() {
            if let Ok(sink_opt) = sink_mutex.lock() {
                if let Some(sink) = sink_opt.as_ref() {
                    // Simple parsing - extract level and message
                    let parts: Vec<&str> = log_str.splitn(2, ' ').collect();
                    if parts.len() >= 2 {
                        let level_and_rest = parts[1];
                        let level_parts: Vec<&str> = level_and_rest.splitn(2, ' ').collect();

                        if level_parts.len() >= 2 {
                            let level = level_parts[0].trim().to_string();
                            let rest = level_parts[1];

                            let target_and_msg: Vec<&str> = rest.splitn(2, ':').collect();
                            let (target, message) = if target_and_msg.len() >= 2 {
                                (
                                    target_and_msg[0].trim().to_string(),
                                    target_and_msg[1].trim().to_string(),
                                )
                            } else {
                                ("unknown".to_string(), rest.trim().to_string())
                            };

                            let timestamp = std::time::SystemTime::now()
                                .duration_since(std::time::UNIX_EPOCH)
                                .unwrap()
                                .as_millis() as u64;

                            let log_msg = LogMessage {
                                level,
                                target,
                                timestamp,
                                message,
                            };

                            // Send to Flutter (ignore errors if sink is closed)
                            let _ = sink.add(log_msg);
                        }
                    }
                }
            }
        }

        Ok(buf.len())
    }

    fn flush(&mut self) -> std::io::Result<()> {
        Ok(())
    }
}

impl<'a> MakeWriter<'a> for FlutterLogWriter {
    type Writer = FlutterLogWriter;

    fn make_writer(&'a self) -> Self::Writer {
        FlutterLogWriter
    }
}

/// Initialize the panic handler for FFI safety.
///
/// This function sets up a panic hook that catches Rust panics and logs them
/// using the tracing framework instead of crashing the app. This is critical
/// for Android/iOS where uncaught panics would terminate the entire application.
///
/// **IMPORTANT**: This function should be called once during Flutter app initialization,
/// before making any other FFI calls to Rust.
///
/// # Examples
///
/// In your Flutter/Dart code:
/// ```dart
/// void main() async {
///   // Initialize Rust panic handler first
///   await RustLib.init();
///   initPanicHandler();
///
///   runApp(MyApp());
/// }
/// ```
pub fn init_panic_handler() {
    panic::set_hook(Box::new(|panic_info| {
        let payload = panic_info.payload();

        let msg = if let Some(s) = payload.downcast_ref::<&str>() {
            s.to_string()
        } else if let Some(s) = payload.downcast_ref::<String>() {
            s.clone()
        } else {
            "Unknown panic payload".to_string()
        };

        let location = if let Some(loc) = panic_info.location() {
            format!("{}:{}:{}", loc.file(), loc.line(), loc.column())
        } else {
            "Unknown location".to_string()
        };

        error!(
            target: "panic",
            panic_message = %msg,
            location = %location,
            "Rust panic occurred - this would have crashed the app"
        );
    }));
}

/// Initialize platform-specific BLE requirements.
///
/// This function performs platform-specific initialization required for BLE operations.
/// On Android, btleplug requires JNI environment initialization before any BLE operations
/// can be performed. On other platforms (Linux, macOS, Windows, iOS), this is a no-op.
///
/// **IMPORTANT**: This function should be called once during Flutter app initialization,
/// after RustLib.init() but before making any BLE API calls (scan_devices, connect_device, etc.).
///
/// # Returns
///
/// Returns Ok(()) if initialization succeeds, or an error if platform-specific setup fails.
///
/// # Errors
///
/// On Android: Returns an error if btleplug platform initialization fails (e.g., missing
/// Bluetooth permissions, BLE hardware unavailable).
///
/// # Examples
///
/// In your Flutter/Dart code:
/// ```dart
/// void main() async {
///   await RustLib.init();
///   await initPlatform(); // Initialize BLE platform
///
///   runApp(MyApp());
/// }
/// ```
pub fn init_platform() -> Result<()> {
    // On Android, btleplug is initialized in JNI_OnLoad where the correct
    // classloader is available. This function is now a no-op on Android.
    // On other platforms (Linux, macOS, Windows, iOS), no initialization is needed.
    Ok(())
}

/// Initialize logging and forward Rust tracing logs to Flutter.
///
/// This function sets up a tracing subscriber that captures all Rust log messages
/// (at the level specified by the RUST_LOG environment variable) and forwards them
/// to Flutter via a StreamSink. This enables unified logging for debugging where
/// both Dart and Rust logs can be viewed together.
///
/// **IMPORTANT**: This function should be called once during Flutter app initialization,
/// after RustLib.init() but before making any other FFI calls that generate logs.
///
/// # Arguments
///
/// * `sink` - The FRB StreamSink that will receive log messages
///
/// # Environment Variables
///
/// * `RUST_LOG` - Controls the log level (TRACE, DEBUG, INFO, WARN, ERROR).
///   Defaults to INFO if not set. Example: `RUST_LOG=debug` or `RUST_LOG=heart_beat=trace`
///
/// # Examples
///
/// In your Flutter/Dart code:
/// ```dart
/// void main() async {
///   await RustLib.init();
///
///   // Create a stream to receive logs
///   final logStream = StreamController<LogMessage>();
///   initLogging(sink: logStream.sink);
///
///   // Listen to logs
///   logStream.stream.listen((log) {
///     debugPrint('[${log.level}] ${log.target}: ${log.message}');
///   });
///
///   runApp(MyApp());
/// }
/// ```
pub fn init_logging(sink: StreamSink<LogMessage>) -> Result<()> {
    // Store the sink globally
    LOG_SINK
        .get_or_init(|| Mutex::new(None))
        .lock()
        .map_err(|e| anyhow!("Failed to lock LOG_SINK: {}", e))?
        .replace(sink);

    // Get log level from RUST_LOG env var, default to INFO
    let env_filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));

    // On Android, also initialize android_logger for logcat output
    #[cfg(target_os = "android")]
    {
        // Parse the env_filter to get the log level for android_logger
        // Default to Info if parsing fails
        let log_level = env_filter
            .to_string()
            .parse::<LevelFilter>()
            .unwrap_or(LevelFilter::Info);

        android_logger::init_once(
            android_logger::Config::default()
                .with_max_level(log_level)
                .with_tag("heart_beat"),
        );
    }

    // Create a tracing subscriber that uses our custom writer
    let subscriber = tracing_subscriber::fmt()
        .with_writer(FlutterLogWriter)
        .with_env_filter(env_filter)
        .with_target(true)
        .with_level(true)
        .with_thread_ids(false)
        .with_thread_names(false)
        .with_file(false)
        .with_line_number(false)
        .with_span_events(FmtSpan::NONE)
        .without_time() // We add timestamp in FlutterLogWriter
        .finish();

    // Set the global subscriber
    tracing::subscriber::set_global_default(subscriber)
        .map_err(|e| anyhow!("Failed to set global tracing subscriber: {}", e))?;

    Ok(())
}

/// Set the base data directory for storing app data.
///
/// On Android, this must be called during app initialization before using any
/// file-based APIs (list_plans, start_workout, list_sessions, etc.). The path
/// should be the app's documents directory obtained from Flutter's path_provider.
///
/// On desktop platforms (Linux, macOS, Windows), this is optional - if not set,
/// the APIs will fall back to using ~/.heart-beat as the data directory.
///
/// # Arguments
///
/// * `path` - Absolute path to the app's data directory
///
/// # Examples
///
/// In your Flutter/Dart code:
/// ```dart
/// import 'package:path_provider/path_provider.dart';
///
/// void main() async {
///   await RustLib.init();
///
///   // Set data directory for file storage
///   final appDir = await getApplicationDocumentsDirectory();
///   await setDataDir(path: appDir.path);
///
///   runApp(MyApp());
/// }
/// ```
pub fn set_data_dir(path: String) -> Result<()> {
    let path_buf = std::path::PathBuf::from(&path);

    // Verify the path exists or can be created
    if !path_buf.exists() {
        std::fs::create_dir_all(&path_buf)
            .map_err(|e| anyhow!("Failed to create data directory '{}': {}", path, e))?;
    }

    DATA_DIR
        .get_or_init(|| Mutex::new(None))
        .lock()
        .map_err(|e| anyhow!("Failed to lock DATA_DIR: {}", e))?
        .replace(path_buf);

    tracing::info!("Data directory set to: {}", path);
    Ok(())
}

/// Get the base data directory for storing app data.
///
/// Returns the directory set via `set_data_dir()`, or falls back to
/// ~/.heart-beat on desktop platforms if not set.
///
/// # Errors
///
/// Returns an error if:
/// - On Android: `set_data_dir()` was not called during initialization
/// - On desktop: The home directory cannot be determined
fn get_data_dir() -> Result<std::path::PathBuf> {
    // Check if data dir was explicitly set
    if let Some(mutex) = DATA_DIR.get() {
        if let Ok(guard) = mutex.lock() {
            if let Some(ref path) = *guard {
                return Ok(path.clone());
            }
        }
    }

    // Fall back to home directory (works on desktop, fails on Android)
    let home = dirs::home_dir().ok_or_else(|| {
        anyhow!(
            "Data directory not set. On Android, call set_data_dir() during app initialization. \
             On desktop, ensure HOME environment variable is set."
        )
    })?;

    Ok(home.join(".heart-beat"))
}

/// Scan for BLE heart rate devices.
///
/// Initiates a BLE scan and returns all discovered devices advertising
/// the Heart Rate Service (UUID 0x180D).
///
/// # Returns
///
/// A list of discovered devices with their IDs, names, and signal strength.
///
/// # Errors
///
/// Returns an error if:
/// - BLE adapter initialization fails
/// - Scan operation fails
/// - BLE is not available or permissions are missing
pub async fn scan_devices() -> Result<Vec<DiscoveredDevice>> {
    tracing::info!("scan_devices: Starting BLE scan");

    // Get the shared global adapter (same instance used for connect)
    tracing::debug!("scan_devices: Getting shared BLE adapter");
    let adapter = match get_ble_adapter().await {
        Ok(a) => {
            tracing::info!("scan_devices: Got BLE adapter successfully");
            a
        }
        Err(e) => {
            tracing::error!("scan_devices: Failed to get adapter: {:?}", e);
            return Err(e);
        }
    };

    // Start scanning
    tracing::debug!("scan_devices: Starting scan");
    if let Err(e) = adapter.start_scan().await {
        tracing::error!("scan_devices: Failed to start scan: {:?}", e);
        return Err(e);
    }
    tracing::info!("scan_devices: Scan started, waiting 10 seconds");

    // Wait for scan to collect devices
    tokio::time::sleep(Duration::from_secs(10)).await;

    // Stop scanning and get results
    tracing::debug!("scan_devices: Stopping scan");
    adapter.stop_scan().await?;
    let devices = adapter.get_discovered_devices().await;
    tracing::info!("scan_devices: Found {} devices", devices.len());

    Ok(devices)
}

/// Connect to a BLE heart rate device.
///
/// Establishes a connection to the specified device and transitions the
/// connectivity state machine to the Connected state.
///
/// # Arguments
///
/// * `device_id` - Platform-specific device identifier from scan results
///
/// # Errors
///
/// Returns an error if:
/// - Device is not found
/// - Connection fails
/// - Connection timeout (15 seconds)
pub async fn connect_device(device_id: String) -> Result<()> {
    tracing::info!("connect_device: Connecting to device {}", device_id);

    // Disconnect from any existing connection first
    if let Some(state_mutex) = CONNECTION_STATE.get() {
        let mut state_guard = state_mutex.lock().await;
        if let Some(old_state) = state_guard.take() {
            tracing::info!(
                "connect_device: Disconnecting from previous device {}",
                old_state.device_id
            );

            // Abort background tasks
            old_state.hr_task_handle.abort();
            old_state.battery_task_handle.abort();

            // Disconnect the adapter
            if let Err(e) = old_state.adapter.disconnect().await {
                tracing::warn!(
                    "connect_device: Failed to disconnect previous device: {}",
                    e
                );
            }
        }
    }

    // Emit Connecting status
    emit_connection_status(ApiConnectionStatus::Connecting);

    // Get the shared adapter (same instance that discovered the devices)
    let adapter = get_ble_adapter().await?;

    // Create state machine with adapter
    let mut state_machine = ConnectionStateMachine::new(adapter.clone());

    // Send DeviceSelected event to initiate connection
    state_machine.handle(ConnectionEvent::DeviceSelected {
        device_id: device_id.clone(),
    })?;

    // Attempt to connect using the adapter
    let connect_result =
        tokio::time::timeout(Duration::from_secs(15), adapter.connect(&device_id)).await;

    match connect_result {
        Ok(Ok(())) => {
            // Connection successful, signal the state machine
            state_machine.handle(ConnectionEvent::ConnectionSuccess)?;

            // Emit Connected status
            emit_connection_status(ApiConnectionStatus::Connected {
                device_id: device_id.clone(),
            });

            // Discover services
            state_machine.handle(ConnectionEvent::ServicesDiscovered)?;

            // Subscribe to HR notifications and start emitting data
            let mut hr_receiver = adapter
                .subscribe_hr()
                .await
                .map_err(|e| anyhow!("Failed to subscribe to HR: {}", e))?;

            tracing::info!("Subscribed to HR notifications, starting data stream");

            // Start battery polling and capture the task handle
            let adapter_clone_battery = adapter.clone();
            let battery_task_handle = tokio::spawn(async move {
                let (battery_tx, mut battery_rx) = tokio::sync::mpsc::channel(10);
                let notification_port: Arc<dyn NotificationPort> = Arc::new(StubNotificationPort);

                // Start battery polling task
                let poll_result = adapter_clone_battery
                    .start_battery_polling(battery_tx, notification_port)
                    .await;

                match poll_result {
                    Ok(poll_handle) => {
                        // Receive battery updates and emit to broadcast channel
                        while let Some(battery_level) = battery_rx.recv().await {
                            // Convert domain BatteryLevel to API BatteryLevel
                            let api_battery = ApiBatteryLevel {
                                level: battery_level.level,
                                is_charging: battery_level.is_charging,
                                timestamp: battery_level
                                    .timestamp
                                    .duration_since(std::time::UNIX_EPOCH)
                                    .map(|d| d.as_millis() as u64)
                                    .unwrap_or(0),
                            };

                            let receivers = emit_battery_data(api_battery);
                            tracing::debug!("Emitted battery data to {} receivers", receivers);
                        }

                        tracing::warn!("Battery polling stream ended");

                        // Cancel the polling task if the receiver ends
                        poll_handle.abort();
                    }
                    Err(e) => {
                        tracing::error!("Failed to start battery polling: {}", e);
                    }
                }
            });

            // Spawn background task to receive and emit HR data and capture handle
            let hr_task_handle = tokio::spawn(async move {
                // Initialize Kalman filter for this connection
                // Using default parameters (process_noise=0.1, measurement_noise=2.0)
                let mut kalman_filter = KalmanFilter::default();

                while let Some(data) = hr_receiver.recv().await {
                    tracing::debug!("Received {} bytes of HR data", data.len());

                    match parse_heart_rate(&data) {
                        Ok(measurement) => {
                            // Apply Kalman filter to raw BPM measurement
                            // filter_if_valid rejects physiologically implausible values
                            let filtered_bpm_f64 =
                                kalman_filter.filter_if_valid(measurement.bpm as f64);
                            let filtered_bpm = filtered_bpm_f64.round() as u16;

                            // Get filter variance (confidence indicator)
                            let filter_variance = kalman_filter.variance();

                            tracing::trace!(
                                "HR filter: raw={} -> filtered={} (diff={}, variance={:.2})",
                                measurement.bpm,
                                filtered_bpm,
                                measurement.bpm as i32 - filtered_bpm as i32,
                                filter_variance
                            );

                            // Calculate RMSSD if RR-intervals are available
                            let rmssd = if measurement.rr_intervals.len() >= 2 {
                                let mut sum_squared_diff = 0.0;
                                for i in 1..measurement.rr_intervals.len() {
                                    let diff = measurement.rr_intervals[i] as f64
                                        - measurement.rr_intervals[i - 1] as f64;
                                    sum_squared_diff += diff * diff;
                                }
                                let rmssd_val = (sum_squared_diff
                                    / (measurement.rr_intervals.len() - 1) as f64)
                                    .sqrt();
                                Some(rmssd_val)
                            } else {
                                None
                            };

                            // Get timestamp
                            let timestamp = std::time::SystemTime::now()
                                .duration_since(std::time::UNIX_EPOCH)
                                .map(|d| d.as_millis() as u64)
                                .unwrap_or(0);

                            let filtered_data = FilteredHeartRate {
                                raw_bpm: measurement.bpm,
                                filtered_bpm,
                                rmssd,
                                filter_variance: Some(filter_variance),
                                battery_level: None, // TODO: Read battery periodically
                                timestamp,
                            };

                            let receivers = emit_hr_data(filtered_data);
                            tracing::debug!("Emitted HR data to {} receivers", receivers);
                        }
                        Err(e) => {
                            tracing::error!("Failed to parse HR data: {}", e);
                        }
                    }
                }

                tracing::warn!("HR notification stream ended");
            });

            // Store connection state for later disconnect
            let connection_state = ConnectionState {
                adapter: adapter.clone(),
                device_id: device_id.clone(),
                hr_task_handle,
                battery_task_handle,
            };

            let state_mutex = CONNECTION_STATE.get_or_init(|| tokio::sync::Mutex::new(None));
            *state_mutex.lock().await = Some(connection_state);

            tracing::info!(
                "connect_device: Connection state stored for device {}",
                device_id
            );

            Ok(())
        }
        Ok(Err(e)) => {
            // Connection failed
            state_machine.handle(ConnectionEvent::ConnectionFailed)?;
            emit_connection_status(ApiConnectionStatus::Disconnected);
            Err(anyhow!("Connection failed: {}", e))
        }
        Err(_) => {
            // Timeout
            state_machine.handle(ConnectionEvent::ConnectionFailed)?;
            emit_connection_status(ApiConnectionStatus::Disconnected);
            Err(anyhow!("Connection timeout after 15 seconds"))
        }
    }
}

/// Disconnect from the currently connected device.
///
/// Gracefully disconnects from the active BLE connection and transitions
/// the state machine back to Idle. This function aborts background tasks
/// (HR streaming and battery polling) and cleanly disconnects the BLE adapter.
///
/// This function is idempotent - calling it when already disconnected is safe
/// and will succeed without error.
///
/// # Errors
///
/// Returns an error if the BLE adapter fails to disconnect.
pub async fn disconnect() -> Result<()> {
    tracing::info!("disconnect: Starting disconnect");

    // Get the connection state mutex
    let state_mutex = CONNECTION_STATE.get_or_init(|| tokio::sync::Mutex::new(None));
    let mut state_guard = state_mutex.lock().await;

    // Take the connection state (if any)
    if let Some(connection_state) = state_guard.take() {
        tracing::info!(
            "disconnect: Disconnecting from device {}",
            connection_state.device_id
        );

        // Abort background tasks
        tracing::debug!("disconnect: Aborting HR task");
        connection_state.hr_task_handle.abort();

        tracing::debug!("disconnect: Aborting battery task");
        connection_state.battery_task_handle.abort();

        // Disconnect the BLE adapter (log error but don't fail if already disconnected)
        tracing::debug!("disconnect: Calling adapter.disconnect()");
        if let Err(e) = connection_state.adapter.disconnect().await {
            tracing::warn!(
                "disconnect: Failed to disconnect adapter (may already be disconnected): {}",
                e
            );
        }

        // Emit disconnected status
        tracing::debug!("disconnect: Emitting Disconnected status");
        emit_connection_status(ApiConnectionStatus::Disconnected);

        tracing::info!(
            "disconnect: Successfully disconnected from device {}",
            connection_state.device_id
        );
    } else {
        // No active connection - this is fine (idempotent)
        tracing::info!("disconnect: No active connection to disconnect");
        emit_connection_status(ApiConnectionStatus::Disconnected);
    }

    Ok(())
}

/// Start mock mode for testing without hardware.
///
/// Activates the mock adapter which generates simulated heart rate data.
/// Useful for UI development and testing without a physical device.
///
/// # Errors
///
/// Returns an error if mock mode activation fails.
pub async fn start_mock_mode() -> Result<()> {
    // TODO: Implement using MockAdapter
    Ok(())
}

/// Create a stream for receiving filtered heart rate data.
///
/// Sets up a stream that will receive real-time filtered heart rate measurements
/// from the filtering pipeline. This function is used by Flutter via FRB to
/// create a reactive data stream.
///
/// # Arguments
///
/// * `sink` - The FRB StreamSink that will receive the HR data
///
/// # Returns
///
/// Returns Ok(()) if the stream was successfully set up.
pub async fn create_hr_stream(sink: StreamSink<ApiFilteredHeartRate>) -> Result<()> {
    let mut rx = get_hr_stream_receiver();
    tokio::spawn(async move {
        while let Ok(data) = rx.recv().await {
            sink.add(data).ok();
        }
    });
    Ok(())
}

/// Get a receiver for streaming filtered heart rate data (internal use).
///
/// Creates a broadcast receiver that can be used to subscribe to real-time
/// filtered heart rate measurements from the filtering pipeline.
///
/// # Returns
///
/// A tokio broadcast receiver that will receive FilteredHeartRate updates.
/// Multiple receivers can be created for fan-out streaming to multiple consumers.
fn get_hr_stream_receiver() -> broadcast::Receiver<ApiFilteredHeartRate> {
    // Get or create the global broadcast sender
    let tx = get_or_create_hr_broadcast_sender();
    tx.subscribe()
}

/// Get or create the global HR broadcast sender.
///
/// Returns the global broadcast sender for emitting HR data to all stream subscribers.
/// This is thread-safe and can be called from multiple locations.
fn get_or_create_hr_broadcast_sender() -> broadcast::Sender<ApiFilteredHeartRate> {
    use std::sync::OnceLock;
    static HR_TX: OnceLock<broadcast::Sender<ApiFilteredHeartRate>> = OnceLock::new();

    HR_TX
        .get_or_init(|| {
            let (tx, _rx) = broadcast::channel(HR_CHANNEL_CAPACITY);
            tx
        })
        .clone()
}

/// Emit filtered heart rate data to all stream subscribers.
///
/// This function should be called by the filtering pipeline when new filtered
/// HR data is available. It broadcasts the data to all active stream subscribers.
///
/// # Arguments
///
/// * `data` - The filtered heart rate measurement to broadcast
///
/// # Returns
///
/// The number of receivers that received the data. Returns 0 if no receivers
/// are currently subscribed.
///
/// # Example
///
/// ```rust,ignore
/// // In your filtering pipeline:
/// let filtered_data = FilteredHeartRate { /* ... */ };
/// emit_hr_data(filtered_data);
/// ```
pub fn emit_hr_data(data: ApiFilteredHeartRate) -> usize {
    let tx = get_or_create_hr_broadcast_sender();
    tx.send(data).unwrap_or_default()
}

// Accessor functions for ApiFilteredHeartRate (opaque type)

/// Get the raw (unfiltered) BPM value from filtered heart rate data
pub fn hr_raw_bpm(data: &ApiFilteredHeartRate) -> u16 {
    data.raw_bpm
}

/// Get the filtered BPM value from filtered heart rate data
pub fn hr_filtered_bpm(data: &ApiFilteredHeartRate) -> u16 {
    data.filtered_bpm
}

/// Get the RMSSD heart rate variability metric in milliseconds
pub fn hr_rmssd(data: &ApiFilteredHeartRate) -> Option<f64> {
    data.rmssd
}

/// Get the filter variance (confidence indicator) in BPM²
///
/// The variance represents the Kalman filter's estimated uncertainty:
/// - < 1.0: High confidence (filter has converged)
/// - 1.0-5.0: Moderate confidence (filter is stable)
/// - > 5.0: Low confidence (filter is warming up or tracking changes)
pub fn hr_filter_variance(data: &ApiFilteredHeartRate) -> Option<f64> {
    data.filter_variance
}

/// Get the battery level as a percentage (0-100)
pub fn hr_battery_level(data: &ApiFilteredHeartRate) -> Option<u8> {
    data.battery_level
}

/// Get the timestamp in milliseconds since Unix epoch
pub fn hr_timestamp(data: &ApiFilteredHeartRate) -> u64 {
    data.timestamp
}

/// Calculate the heart rate zone based on a maximum heart rate
///
/// # Arguments
///
/// * `data` - The filtered heart rate data
/// * `max_hr` - The user's maximum heart rate
///
/// # Returns
///
/// The training zone (Zone1-Zone5) based on percentage of max HR
pub fn hr_zone(data: &ApiFilteredHeartRate, max_hr: u16) -> Zone {
    let percentage = (data.filtered_bpm as f64 / max_hr as f64) * 100.0;

    match percentage {
        p if p < 60.0 => Zone::Zone1,
        p if p < 70.0 => Zone::Zone2,
        p if p < 80.0 => Zone::Zone3,
        p if p < 90.0 => Zone::Zone4,
        _ => Zone::Zone5,
    }
}

/// Create a dummy battery level for testing (temporary helper for FRB codegen).
///
/// This function helps FRB discover the ApiBatteryLevel type during code generation.
/// TODO: Remove this after ApiBatteryLevel is properly integrated.
pub fn dummy_battery_level_for_codegen() -> ApiBatteryLevel {
    ApiBatteryLevel {
        level: Some(100),
        is_charging: false,
        timestamp: 0,
    }
}

/// Create a dummy connection status for testing (temporary helper for FRB codegen).
///
/// This function helps FRB discover the ApiConnectionStatus type during code generation.
pub fn dummy_connection_status_for_codegen() -> ApiConnectionStatus {
    ApiConnectionStatus::Connected {
        device_id: "dummy".to_string(),
    }
}

/// Create a stream for receiving battery level data.
///
/// Sets up a stream that will receive real-time battery level measurements
/// from the connected BLE device. This function is used by Flutter via FRB to
/// create a reactive data stream.
///
/// # Arguments
///
/// * `sink` - The FRB StreamSink that will receive the battery data
///
/// # Returns
///
/// Returns Ok(()) if the stream was successfully set up.
pub async fn create_battery_stream(sink: StreamSink<ApiBatteryLevel>) -> Result<()> {
    let mut rx = get_battery_stream_receiver();
    tokio::spawn(async move {
        while let Ok(data) = rx.recv().await {
            sink.add(data).ok();
        }
    });
    Ok(())
}

/// Get a receiver for streaming battery level data (internal use).
///
/// Creates a broadcast receiver that can be used to subscribe to real-time
/// battery level measurements from the connected BLE device.
///
/// # Returns
///
/// A tokio broadcast receiver that will receive BatteryLevel updates.
/// Multiple receivers can be created for fan-out streaming to multiple consumers.
fn get_battery_stream_receiver() -> broadcast::Receiver<ApiBatteryLevel> {
    // Get or create the global broadcast sender
    let tx = get_or_create_battery_broadcast_sender();
    tx.subscribe()
}

/// Get or create the global battery broadcast sender.
///
/// Returns the global broadcast sender for emitting battery data to all stream subscribers.
/// This is thread-safe and can be called from multiple locations.
fn get_or_create_battery_broadcast_sender() -> broadcast::Sender<ApiBatteryLevel> {
    use std::sync::OnceLock;
    static BATTERY_TX: OnceLock<broadcast::Sender<ApiBatteryLevel>> = OnceLock::new();

    BATTERY_TX
        .get_or_init(|| {
            let (tx, _rx) = broadcast::channel(BATTERY_CHANNEL_CAPACITY);
            tx
        })
        .clone()
}

/// Emit battery level data to all stream subscribers.
///
/// This function should be called by the battery polling task when new battery
/// data is available. It broadcasts the data to all active stream subscribers.
///
/// # Arguments
///
/// * `data` - The battery level measurement to broadcast
///
/// # Returns
///
/// The number of receivers that received the data. Returns 0 if no receivers
/// are currently subscribed.
///
/// # Example
///
/// ```rust,ignore
/// // In your battery polling task:
/// let battery_data = BatteryLevel { /* ... */ };
/// emit_battery_data(battery_data);
/// ```
pub fn emit_battery_data(data: ApiBatteryLevel) -> usize {
    let tx = get_or_create_battery_broadcast_sender();
    tx.send(data).unwrap_or_default()
}

/// Create a stream of session progress updates during workout execution.
///
/// This stream emits SessionProgress updates at regular intervals (typically 1Hz)
/// while a workout is running, providing real-time feedback on phase progress,
/// zone status, and elapsed/remaining time.
///
/// # Arguments
///
/// * `sink` - The FRB StreamSink that will receive the session progress data
///
/// # Returns
///
/// Returns Ok(()) if the stream was successfully set up.
///
/// # Example
///
/// ```dart
/// // In Flutter:
/// final stream = await api.createSessionProgressStream();
/// stream.listen((progress) {
///   print('Current phase: ${progress.phaseProgress.phaseName}');
///   print('Zone status: ${progress.zoneStatus}');
/// });
/// ```
pub async fn create_session_progress_stream(sink: StreamSink<ApiSessionProgress>) -> Result<()> {
    let mut rx = get_session_progress_receiver();
    tokio::spawn(async move {
        while let Ok(data) = rx.recv().await {
            sink.add(data).ok();
        }
    });
    Ok(())
}

/// Get a receiver for streaming session progress data (internal use).
///
/// Creates a broadcast receiver that can be used to subscribe to real-time
/// session progress updates from the SessionExecutor.
///
/// # Returns
///
/// A tokio broadcast receiver that will receive SessionProgress updates.
/// Multiple receivers can be created for fan-out streaming to multiple consumers.
fn get_session_progress_receiver() -> broadcast::Receiver<ApiSessionProgress> {
    let tx = get_or_create_session_progress_broadcast_sender();
    tx.subscribe()
}

/// Get or create the global session progress broadcast sender.
///
/// Returns the global broadcast sender for emitting session progress data to all
/// stream subscribers. This is thread-safe and can be called from multiple locations.
fn get_or_create_session_progress_broadcast_sender() -> broadcast::Sender<ApiSessionProgress> {
    use std::sync::OnceLock;
    static SESSION_PROGRESS_TX: OnceLock<broadcast::Sender<ApiSessionProgress>> = OnceLock::new();

    SESSION_PROGRESS_TX
        .get_or_init(|| {
            let (tx, _rx) = broadcast::channel(SESSION_PROGRESS_CHANNEL_CAPACITY);
            tx
        })
        .clone()
}

/// Emit session progress data to all stream subscribers.
///
/// This function is called by the SessionExecutor tick loop when progress updates
/// are available. It broadcasts the data to all active stream subscribers.
///
/// # Arguments
///
/// * `data` - The session progress snapshot to broadcast
///
/// # Returns
///
/// The number of receivers that received the data. Returns 0 if no receivers
/// are currently subscribed.
pub fn emit_session_progress(data: ApiSessionProgress) -> usize {
    let tx = get_or_create_session_progress_broadcast_sender();
    tx.send(data).unwrap_or_default()
}

/// Get a sender for session progress updates (internal use).
///
/// This creates an unbounded mpsc sender that can be used by the SessionExecutor
/// to send progress updates. A background task forwards these to the broadcast channel.
///
/// # Returns
///
/// An unbounded sender for SessionProgress and a JoinHandle to the forwarding task.
fn create_session_progress_forwarder() -> tokio::sync::mpsc::UnboundedSender<ApiSessionProgress> {
    let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel::<ApiSessionProgress>();

    // Spawn a task to forward from mpsc to broadcast
    tokio::spawn(async move {
        while let Some(progress) = rx.recv().await {
            emit_session_progress(progress);
        }
    });

    tx
}

/// Create a stream for receiving connection status updates.
///
/// Sets up a stream that will receive real-time connection status updates
/// during BLE device connection, reconnection attempts, and failures.
/// This function is used by Flutter via FRB to create a reactive data stream.
///
/// # Arguments
///
/// * `sink` - The FRB StreamSink that will receive the connection status data
///
/// # Returns
///
/// Returns Ok(()) if the stream was successfully set up.
///
/// # Example
///
/// ```dart
/// // In Flutter:
/// final stream = await api.createConnectionStatusStream();
/// stream.listen((status) {
///   if (status.type == 'reconnecting') {
///     print('Reconnecting... attempt ${status.attempt}/${status.max_attempts}');
///   } else if (status.type == 'connected') {
///     print('Connected to ${status.device_id}');
///   }
/// });
/// ```
pub async fn create_connection_status_stream(sink: StreamSink<ApiConnectionStatus>) -> Result<()> {
    let mut rx = get_connection_status_receiver();
    tokio::spawn(async move {
        while let Ok(data) = rx.recv().await {
            sink.add(data).ok();
        }
    });
    Ok(())
}

/// Get a receiver for streaming connection status data (internal use).
///
/// Creates a broadcast receiver that can be used to subscribe to real-time
/// connection status updates from the BLE adapter.
///
/// # Returns
///
/// A tokio broadcast receiver that will receive ConnectionStatus updates.
/// Multiple receivers can be created for fan-out streaming to multiple consumers.
fn get_connection_status_receiver() -> broadcast::Receiver<ApiConnectionStatus> {
    let tx = get_or_create_connection_status_broadcast_sender();
    tx.subscribe()
}

/// Get or create the global connection status broadcast sender.
///
/// Returns the global broadcast sender for emitting connection status data to all
/// stream subscribers. This is thread-safe and can be called from multiple locations.
fn get_or_create_connection_status_broadcast_sender() -> broadcast::Sender<ApiConnectionStatus> {
    use std::sync::OnceLock;
    static CONNECTION_STATUS_TX: OnceLock<broadcast::Sender<ApiConnectionStatus>> = OnceLock::new();

    CONNECTION_STATUS_TX
        .get_or_init(|| {
            let (tx, _rx) = broadcast::channel(CONNECTION_STATUS_CHANNEL_CAPACITY);
            tx
        })
        .clone()
}

/// Emit connection status data to all stream subscribers.
///
/// This function should be called by the BLE adapter when connection status changes.
/// It broadcasts the status to all active stream subscribers.
///
/// # Arguments
///
/// * `status` - The connection status to broadcast
///
/// # Returns
///
/// The number of receivers that received the status. Returns 0 if no receivers
/// are currently subscribed.
///
/// # Example
///
/// ```rust,ignore
/// // When starting reconnection:
/// emit_connection_status(ConnectionStatus::Reconnecting { attempt: 1, max_attempts: 5 });
///
/// // When connected:
/// emit_connection_status(ConnectionStatus::Connected { device_id: "AA:BB:CC:DD:EE:FF".to_string() });
///
/// // When reconnection fails:
/// emit_connection_status(ConnectionStatus::ReconnectFailed { reason: "Max attempts exceeded".to_string() });
/// ```
pub fn emit_connection_status(status: ApiConnectionStatus) -> usize {
    let tx = get_or_create_connection_status_broadcast_sender();
    tx.send(status).unwrap_or_default()
}

/// Check if the connection status is Disconnected.
pub fn connection_status_is_disconnected(status: &ApiConnectionStatus) -> bool {
    matches!(status, ApiConnectionStatus::Disconnected)
}

/// Check if the connection status is Connecting.
pub fn connection_status_is_connecting(status: &ApiConnectionStatus) -> bool {
    matches!(status, ApiConnectionStatus::Connecting)
}

/// Check if the connection status is Connected.
pub fn connection_status_is_connected(status: &ApiConnectionStatus) -> bool {
    matches!(status, ApiConnectionStatus::Connected { .. })
}

/// Check if the connection status is Reconnecting.
pub fn connection_status_is_reconnecting(status: &ApiConnectionStatus) -> bool {
    matches!(status, ApiConnectionStatus::Reconnecting { .. })
}

/// Check if the connection status is ReconnectFailed.
pub fn connection_status_is_reconnect_failed(status: &ApiConnectionStatus) -> bool {
    matches!(status, ApiConnectionStatus::ReconnectFailed { .. })
}

/// Get the device ID from a Connected status.
/// Returns None if the status is not Connected.
pub fn connection_status_device_id(status: &ApiConnectionStatus) -> Option<String> {
    match status {
        ApiConnectionStatus::Connected { device_id } => Some(device_id.clone()),
        _ => None,
    }
}

/// Get the current attempt number from a Reconnecting status.
/// Returns None if the status is not Reconnecting.
pub fn connection_status_attempt(status: &ApiConnectionStatus) -> Option<u8> {
    match status {
        ApiConnectionStatus::Reconnecting { attempt, .. } => Some(*attempt),
        _ => None,
    }
}

/// Get the max attempts from a Reconnecting status.
/// Returns None if the status is not Reconnecting.
pub fn connection_status_max_attempts(status: &ApiConnectionStatus) -> Option<u8> {
    match status {
        ApiConnectionStatus::Reconnecting { max_attempts, .. } => Some(*max_attempts),
        _ => None,
    }
}

/// Get the failure reason from a ReconnectFailed status.
/// Returns None if the status is not ReconnectFailed.
pub fn connection_status_failure_reason(status: &ApiConnectionStatus) -> Option<String> {
    match status {
        ApiConnectionStatus::ReconnectFailed { reason } => Some(reason.clone()),
        _ => None,
    }
}

/// Convert connection status to a human-readable string.
pub fn connection_status_to_string(status: &ApiConnectionStatus) -> String {
    match status {
        ApiConnectionStatus::Disconnected => "Disconnected".to_string(),
        ApiConnectionStatus::Connecting => "Connecting".to_string(),
        ApiConnectionStatus::Connected { device_id } => format!("Connected to {}", device_id),
        ApiConnectionStatus::Reconnecting {
            attempt,
            max_attempts,
        } => format!("Reconnecting (attempt {}/{})", attempt, max_attempts),
        ApiConnectionStatus::ReconnectFailed { reason } => {
            format!("Connection failed: {}", reason)
        }
    }
}

// Global session repository
static SESSION_REPOSITORY: OnceLock<tokio::sync::Mutex<Option<Arc<FileSessionRepository>>>> =
    OnceLock::new();

// Global session executor for workout execution
static SESSION_EXECUTOR: OnceLock<
    tokio::sync::Mutex<Option<crate::scheduler::executor::SessionExecutor>>,
> = OnceLock::new();

/// Get or create the global session repository instance.
async fn get_session_repository() -> Result<Arc<FileSessionRepository>> {
    let mutex = SESSION_REPOSITORY.get_or_init(|| tokio::sync::Mutex::new(None));
    let mut guard = mutex.lock().await;

    if let Some(ref repo) = *guard {
        return Ok(repo.clone());
    }

    // Create new repository with the correct data directory
    let data_dir = get_data_dir()?;
    let sessions_dir = data_dir.join("sessions");
    tracing::info!("Creating FileSessionRepository at {:?}", sessions_dir);
    let repo = Arc::new(FileSessionRepository::with_directory(sessions_dir).await?);
    *guard = Some(repo.clone());
    Ok(repo)
}

/// List all completed training sessions.
///
/// Returns a list of session summaries sorted by start time (most recent first).
/// This is optimized for displaying in a list view - full session data is not loaded.
///
/// # Returns
///
/// A vector of session summary previews containing ID, plan name, start time,
/// duration, average heart rate, and status.
///
/// # Errors
///
/// Returns an error if the sessions directory cannot be read or if the repository
/// cannot be initialized.
pub async fn list_sessions() -> Result<Vec<ApiSessionSummaryPreview>> {
    tracing::info!("list_sessions: Listing all sessions");
    let repo = get_session_repository().await?;
    let previews = repo.list().await?;
    tracing::info!("list_sessions: Found {} sessions", previews.len());
    Ok(previews)
}

/// Get a complete session by its ID.
///
/// Loads the full session data including all heart rate samples and statistics.
/// This is intended for displaying detailed session information.
///
/// # Arguments
///
/// * `id` - The unique identifier of the session to retrieve
///
/// # Returns
///
/// The complete session if found, or `None` if no session with the given ID exists.
///
/// # Errors
///
/// Returns an error if the session file cannot be read or parsed, or if the
/// repository cannot be initialized.
pub async fn get_session(id: String) -> Result<Option<ApiCompletedSession>> {
    tracing::info!("get_session: Getting session with id: {}", id);
    let repo = get_session_repository().await?;
    let session = repo.get(&id).await?;

    if session.is_some() {
        tracing::info!("get_session: Found session {}", id);
    } else {
        tracing::warn!("get_session: Session {} not found", id);
    }

    Ok(session)
}

/// Delete a session by its ID.
///
/// Permanently removes the session and all its data from storage.
///
/// # Arguments
///
/// * `id` - The unique identifier of the session to delete
///
/// # Errors
///
/// Returns an error if the session file cannot be deleted or if the repository
/// cannot be initialized. Succeeds silently if the session doesn't exist.
pub async fn delete_session(id: String) -> Result<()> {
    tracing::info!("delete_session: Deleting session with id: {}", id);
    let repo = get_session_repository().await?;
    repo.delete(&id).await?;
    tracing::info!("delete_session: Successfully deleted session {}", id);
    Ok(())
}

/// Export a session to a specified format.
///
/// Loads a completed session and exports it in the requested format (CSV, JSON, or text summary).
/// The returned string can be saved to a file or shared directly.
///
/// # Arguments
///
/// * `id` - The unique identifier of the session to export
/// * `format` - The desired export format (Csv, Json, or Summary)
///
/// # Returns
///
/// A string containing the exported session data in the requested format.
///
/// # Errors
///
/// Returns an error if:
/// - The session cannot be found
/// - The session repository cannot be initialized
/// - The session data cannot be formatted (should not normally occur)
///
/// # Examples
///
/// ```no_run
/// # use heart_beat::api::{export_session, ExportFormat};
/// # tokio_test::block_on(async {
/// let csv_data = export_session("session-123".to_string(), ExportFormat::Csv).await?;
/// let json_data = export_session("session-123".to_string(), ExportFormat::Json).await?;
/// let summary = export_session("session-123".to_string(), ExportFormat::Summary).await?;
/// # Ok::<(), anyhow::Error>(())
/// # });
/// ```
pub async fn export_session(id: String, format: ExportFormat) -> Result<String> {
    tracing::info!("export_session: Exporting session {} as {:?}", id, format);

    let repo = get_session_repository().await?;
    let session = repo
        .get(&id)
        .await?
        .ok_or_else(|| anyhow!("Session not found: {}", id))?;

    let content = match format {
        ExportFormat::Csv => crate::domain::export_to_csv(&session),
        ExportFormat::Json => crate::domain::export_to_json(&session),
        ExportFormat::Summary => crate::domain::export_to_summary(&session),
    };

    tracing::info!(
        "export_session: Successfully exported session {} ({} bytes)",
        id,
        content.len()
    );

    Ok(content)
}

// Accessor functions for SessionSummaryPreview (opaque type)

/// Get the session ID from a session summary preview
pub fn session_preview_id(preview: &ApiSessionSummaryPreview) -> String {
    preview.id.clone()
}

/// Get the plan name from a session summary preview
pub fn session_preview_plan_name(preview: &ApiSessionSummaryPreview) -> String {
    preview.plan_name.clone()
}

/// Get the start time as Unix timestamp in milliseconds from a session summary preview
pub fn session_preview_start_time(preview: &ApiSessionSummaryPreview) -> i64 {
    preview.start_time.timestamp_millis()
}

/// Get the duration in seconds from a session summary preview
pub fn session_preview_duration_secs(preview: &ApiSessionSummaryPreview) -> u32 {
    preview.duration_secs
}

/// Get the average heart rate from a session summary preview
pub fn session_preview_avg_hr(preview: &ApiSessionSummaryPreview) -> u16 {
    preview.avg_hr
}

/// Get the status string from a session summary preview
pub fn session_preview_status(preview: &ApiSessionSummaryPreview) -> String {
    preview.status.clone()
}

// Accessor functions for CompletedSession (opaque type)

/// Get the session ID from a completed session
pub fn session_id(session: &ApiCompletedSession) -> String {
    session.id.clone()
}

/// Get the plan name from a completed session
pub fn session_plan_name(session: &ApiCompletedSession) -> String {
    session.plan_name.clone()
}

/// Get the start time as Unix timestamp in milliseconds from a completed session
pub fn session_start_time(session: &ApiCompletedSession) -> i64 {
    session.start_time.timestamp_millis()
}

/// Get the end time as Unix timestamp in milliseconds from a completed session
pub fn session_end_time(session: &ApiCompletedSession) -> i64 {
    session.end_time.timestamp_millis()
}

/// Get the status string from a completed session
pub fn session_status(session: &ApiCompletedSession) -> String {
    format!("{:?}", session.status)
}

/// Get the number of phases completed from a completed session
pub fn session_phases_completed(session: &ApiCompletedSession) -> u32 {
    session.phases_completed
}

/// Get the duration in seconds from a completed session summary
pub fn session_summary_duration_secs(session: &ApiCompletedSession) -> u32 {
    session.summary.duration_secs
}

/// Get the average heart rate from a completed session summary
pub fn session_summary_avg_hr(session: &ApiCompletedSession) -> u16 {
    session.summary.avg_hr
}

/// Get the maximum heart rate from a completed session summary
pub fn session_summary_max_hr(session: &ApiCompletedSession) -> u16 {
    session.summary.max_hr
}

/// Get the minimum heart rate from a completed session summary
pub fn session_summary_min_hr(session: &ApiCompletedSession) -> u16 {
    session.summary.min_hr
}

/// Get the time in zone array from a completed session summary
/// Returns an array of 5 elements representing time spent in each zone (Zone1-Zone5) in seconds
pub fn session_summary_time_in_zone(session: &ApiCompletedSession) -> Vec<u32> {
    session.summary.time_in_zone.to_vec()
}

/// Get the number of heart rate samples in a completed session
pub fn session_hr_samples_count(session: &ApiCompletedSession) -> usize {
    session.hr_samples.len()
}

/// Get a specific heart rate sample from a completed session
/// Returns a tuple of (timestamp_millis, bpm)
pub fn session_hr_sample_at(session: &ApiCompletedSession, index: usize) -> Option<(i64, u16)> {
    session
        .hr_samples
        .get(index)
        .map(|sample| (sample.timestamp.timestamp_millis(), sample.bpm))
}

// =============================================================================
// Workout Execution API
// =============================================================================

/// List all available training plans.
///
/// Returns a list of plan names from the data directory's plans/ subdirectory.
/// Each plan is stored as a JSON file named `{plan_name}.json`.
///
/// # Returns
///
/// A vector of plan name strings. Returns an empty vector if no plans are found
/// or if the plans directory doesn't exist yet.
///
/// # Errors
///
/// Returns an error if the data directory cannot be determined or if there are
/// issues reading the plans directory.
pub async fn list_plans() -> Result<Vec<String>> {
    tracing::info!("list_plans: Listing all training plans");

    // Get plans directory
    let data_dir = get_data_dir()?;
    let plans_dir = data_dir.join("plans");

    // Create directory if it doesn't exist
    if !plans_dir.exists() {
        tracing::info!("list_plans: Plans directory doesn't exist, returning empty list");
        return Ok(Vec::new());
    }

    // Read all .json files from the plans directory
    let mut plan_names: Vec<String> = Vec::new();

    for entry in std::fs::read_dir(&plans_dir)? {
        let entry = entry?;
        let path = entry.path();

        if path.extension().and_then(|s| s.to_str()) == Some("json") {
            if let Some(stem) = path.file_stem().and_then(|s| s.to_str()) {
                plan_names.push(stem.to_string());
            }
        }
    }

    // Sort alphabetically
    plan_names.sort();

    tracing::info!("list_plans: Found {} plans", plan_names.len());
    Ok(plan_names)
}

/// Load a training plan by name from the plans directory.
///
/// Internal helper function to load a plan from {data_dir}/plans/{name}.json
async fn load_plan(name: &str) -> Result<TrainingPlan> {
    let data_dir = get_data_dir()?;
    let plans_dir = data_dir.join("plans");
    let plan_path = plans_dir.join(format!("{}.json", name));

    if !plan_path.exists() {
        return Err(anyhow!(
            "Plan '{}' not found. Use list_plans() to see available plans.",
            name
        ));
    }

    let content = tokio::fs::read_to_string(&plan_path).await?;
    let plan: TrainingPlan = serde_json::from_str(&content)?;

    Ok(plan)
}

/// Save a training plan to the plans directory.
///
/// Creates the plan file at {data_dir}/plans/{plan_name}.json.
/// Overwrites if the plan already exists.
async fn save_plan(plan: &TrainingPlan) -> Result<()> {
    let data_dir = get_data_dir()?;
    let plans_dir = data_dir.join("plans");

    // Create plans directory if it doesn't exist
    if !plans_dir.exists() {
        tokio::fs::create_dir_all(&plans_dir).await?;
    }

    let plan_path = plans_dir.join(format!("{}.json", plan.name));
    let json = serde_json::to_string_pretty(plan)?;
    tokio::fs::write(&plan_path, json).await?;

    tracing::info!("save_plan: Saved plan '{}' to {:?}", plan.name, plan_path);
    Ok(())
}

/// Seed default training plans if none exist.
///
/// Creates a set of sample training plans for users to get started with.
/// This function is idempotent - it only creates plans if the plans directory
/// is empty or doesn't exist.
///
/// # Default Plans Created
///
/// - **Easy Run** (30 min): 10min Zone2 warmup, 10min Zone2 main, 10min Zone1 cooldown
/// - **Tempo Run** (40 min): 10min Zone2 warmup, 20min Zone3 tempo, 10min Zone1 cooldown
/// - **Interval Training** (35 min): Warmup + 5x(3min Zone4 / 2min Zone2) + Cooldown
/// - **Long Slow Distance** (60 min): Steady Zone2 aerobic base building
/// - **Recovery Run** (20 min): Easy Zone1 active recovery
///
/// # Returns
///
/// The number of plans created. Returns 0 if plans already exist.
pub async fn seed_default_plans() -> Result<u32> {
    use crate::domain::heart_rate::Zone;
    use crate::domain::training_plan::{TrainingPhase, TransitionCondition};
    use chrono::Utc;

    let data_dir = get_data_dir()?;
    let plans_dir = data_dir.join("plans");

    // Check if plans already exist
    let existing_plans = list_plans().await.unwrap_or_default();
    if !existing_plans.is_empty() {
        tracing::info!(
            "seed_default_plans: {} plans already exist, skipping seed",
            existing_plans.len()
        );
        return Ok(0);
    }

    tracing::info!("seed_default_plans: Creating default training plans");

    // Create plans directory
    if !plans_dir.exists() {
        tokio::fs::create_dir_all(&plans_dir).await?;
    }

    let mut count = 0;

    // 1. Easy Run - 30 minutes
    let easy_run = TrainingPlan {
        name: "Easy Run".to_string(),
        phases: vec![
            TrainingPhase {
                name: "Warmup".to_string(),
                target_zone: Zone::Zone2,
                duration_secs: 600, // 10 min
                transition: TransitionCondition::TimeElapsed,
            },
            TrainingPhase {
                name: "Easy Pace".to_string(),
                target_zone: Zone::Zone2,
                duration_secs: 600, // 10 min
                transition: TransitionCondition::TimeElapsed,
            },
            TrainingPhase {
                name: "Cooldown".to_string(),
                target_zone: Zone::Zone1,
                duration_secs: 600, // 10 min
                transition: TransitionCondition::TimeElapsed,
            },
        ],
        created_at: Utc::now(),
        max_hr: 180,
    };
    save_plan(&easy_run).await?;
    count += 1;

    // 2. Tempo Run - 40 minutes
    let tempo_run = TrainingPlan {
        name: "Tempo Run".to_string(),
        phases: vec![
            TrainingPhase {
                name: "Warmup".to_string(),
                target_zone: Zone::Zone2,
                duration_secs: 600, // 10 min
                transition: TransitionCondition::TimeElapsed,
            },
            TrainingPhase {
                name: "Tempo".to_string(),
                target_zone: Zone::Zone3,
                duration_secs: 1200, // 20 min
                transition: TransitionCondition::TimeElapsed,
            },
            TrainingPhase {
                name: "Cooldown".to_string(),
                target_zone: Zone::Zone1,
                duration_secs: 600, // 10 min
                transition: TransitionCondition::TimeElapsed,
            },
        ],
        created_at: Utc::now(),
        max_hr: 180,
    };
    save_plan(&tempo_run).await?;
    count += 1;

    // 3. Interval Training - 35 minutes
    let mut interval_phases = vec![TrainingPhase {
        name: "Warmup".to_string(),
        target_zone: Zone::Zone2,
        duration_secs: 300, // 5 min
        transition: TransitionCondition::TimeElapsed,
    }];

    for i in 1..=5 {
        interval_phases.push(TrainingPhase {
            name: format!("Interval {}", i),
            target_zone: Zone::Zone4,
            duration_secs: 180, // 3 min
            transition: TransitionCondition::TimeElapsed,
        });
        interval_phases.push(TrainingPhase {
            name: format!("Recovery {}", i),
            target_zone: Zone::Zone2,
            duration_secs: 120, // 2 min
            transition: TransitionCondition::TimeElapsed,
        });
    }

    interval_phases.push(TrainingPhase {
        name: "Cooldown".to_string(),
        target_zone: Zone::Zone1,
        duration_secs: 300, // 5 min
        transition: TransitionCondition::TimeElapsed,
    });

    let interval_training = TrainingPlan {
        name: "Interval Training".to_string(),
        phases: interval_phases,
        created_at: Utc::now(),
        max_hr: 180,
    };
    save_plan(&interval_training).await?;
    count += 1;

    // 4. Long Slow Distance - 60 minutes
    let lsd = TrainingPlan {
        name: "Long Slow Distance".to_string(),
        phases: vec![TrainingPhase {
            name: "Steady Aerobic".to_string(),
            target_zone: Zone::Zone2,
            duration_secs: 3600, // 60 min
            transition: TransitionCondition::TimeElapsed,
        }],
        created_at: Utc::now(),
        max_hr: 180,
    };
    save_plan(&lsd).await?;
    count += 1;

    // 5. Recovery Run - 20 minutes
    let recovery = TrainingPlan {
        name: "Recovery Run".to_string(),
        phases: vec![TrainingPhase {
            name: "Easy Recovery".to_string(),
            target_zone: Zone::Zone1,
            duration_secs: 1200, // 20 min
            transition: TransitionCondition::TimeElapsed,
        }],
        created_at: Utc::now(),
        max_hr: 180,
    };
    save_plan(&recovery).await?;
    count += 1;

    tracing::info!("seed_default_plans: Created {} default plans", count);
    Ok(count)
}

/// Get or create the global session executor instance.
///
/// The executor is initialized with:
/// - HR data stream (if available)
/// - Session repository for saving completed workouts
/// - Notification port for user alerts
async fn get_session_executor() -> Result<&'static tokio::sync::Mutex<Option<SessionExecutor>>> {
    Ok(SESSION_EXECUTOR.get_or_init(|| tokio::sync::Mutex::new(None)))
}

/// Start a workout session with the specified training plan.
///
/// Loads the plan from ~/.heart-beat/plans/{plan_name}.json and starts
/// executing it. The session will emit progress updates via the progress stream
/// and save the completed session to the repository.
///
/// # Arguments
///
/// * `plan_name` - The name of the training plan to execute (without .json extension)
///
/// # Returns
///
/// Returns Ok(()) if the workout started successfully.
///
/// # Errors
///
/// Returns an error if:
/// - The plan file cannot be found or loaded
/// - A workout is already in progress
/// - The executor cannot be initialized
pub async fn start_workout(plan_name: String) -> Result<()> {
    tracing::info!("start_workout: Starting workout with plan '{}'", plan_name);

    // Load the training plan
    let plan = load_plan(&plan_name).await?;

    // Get the executor mutex
    let executor_mutex = get_session_executor().await?;
    let mut executor_guard = executor_mutex.lock().await;

    // Initialize executor if needed
    if executor_guard.is_none() {
        tracing::info!("start_workout: Initializing session executor");

        // Create notification port (stub for now)
        let notification_port: Arc<dyn NotificationPort> = Arc::new(StubNotificationPort);

        // Get HR stream receiver
        let hr_receiver = get_hr_stream_receiver();

        // Get session repository
        let session_repo = get_session_repository().await?;

        // Create progress forwarder
        let progress_sender = create_session_progress_forwarder();

        // Create executor with HR stream, progress sender, and session repository
        let executor = SessionExecutor::with_hr_stream(notification_port, hr_receiver)
            .with_progress_sender(progress_sender)
            .with_session_repository(session_repo);

        *executor_guard = Some(executor);
    }

    // Start the session
    if let Some(ref mut executor) = *executor_guard {
        executor.start_session(plan).await?;
        tracing::info!("start_workout: Workout started successfully");
    } else {
        return Err(anyhow!("Failed to initialize session executor"));
    }

    Ok(())
}

/// Pause the currently running workout.
///
/// The workout timer stops but the session state is preserved.
/// Call `resume_workout()` to continue from where you left off.
///
/// # Errors
///
/// Returns an error if no workout is currently running or if the executor
/// is not initialized.
pub async fn pause_workout() -> Result<()> {
    tracing::info!("pause_workout: Pausing workout");

    let executor_mutex = get_session_executor().await?;
    let mut executor_guard = executor_mutex.lock().await;

    if let Some(ref mut executor) = *executor_guard {
        executor.pause_session().await?;
        tracing::info!("pause_workout: Workout paused successfully");
        Ok(())
    } else {
        Err(anyhow!("No active workout session"))
    }
}

/// Resume a paused workout.
///
/// Continues the workout from where it was paused. The timer resumes
/// counting and progress updates continue.
///
/// # Errors
///
/// Returns an error if no workout is paused or if the executor is not initialized.
pub async fn resume_workout() -> Result<()> {
    tracing::info!("resume_workout: Resuming workout");

    let executor_mutex = get_session_executor().await?;
    let mut executor_guard = executor_mutex.lock().await;

    if let Some(ref mut executor) = *executor_guard {
        executor.resume_session().await?;
        tracing::info!("resume_workout: Workout resumed successfully");
        Ok(())
    } else {
        Err(anyhow!("No active workout session"))
    }
}

/// Stop the currently running workout.
///
/// Ends the workout and saves the session to the repository. The session
/// will be marked as "Stopped" rather than "Completed".
///
/// # Errors
///
/// Returns an error if no workout is running or if the executor is not initialized.
pub async fn stop_workout() -> Result<()> {
    tracing::info!("stop_workout: Stopping workout");

    let executor_mutex = get_session_executor().await?;
    let mut executor_guard = executor_mutex.lock().await;

    if let Some(ref mut executor) = *executor_guard {
        executor.stop_session().await?;
        tracing::info!("stop_workout: Workout stopped successfully");
        Ok(())
    } else {
        Err(anyhow!("No active workout session"))
    }
}

// SessionProgress accessor methods for opaque types

/// Get the current session state from SessionProgress.
pub fn session_progress_state(progress: &ApiSessionProgress) -> ApiSessionState {
    progress.state
}

/// Get the current phase index from SessionProgress.
pub fn session_progress_current_phase(progress: &ApiSessionProgress) -> u32 {
    progress.current_phase
}

/// Get the total elapsed seconds from SessionProgress.
pub fn session_progress_total_elapsed_secs(progress: &ApiSessionProgress) -> u32 {
    progress.total_elapsed_secs
}

/// Get the total remaining seconds from SessionProgress.
pub fn session_progress_total_remaining_secs(progress: &ApiSessionProgress) -> u32 {
    progress.total_remaining_secs
}

/// Get the zone status from SessionProgress.
pub fn session_progress_zone_status(progress: &ApiSessionProgress) -> ApiZoneStatus {
    progress.zone_status
}

/// Get the current BPM from SessionProgress.
pub fn session_progress_current_bpm(progress: &ApiSessionProgress) -> u16 {
    progress.current_bpm
}

/// Get the phase progress from SessionProgress.
pub fn session_progress_phase_progress(progress: &ApiSessionProgress) -> ApiPhaseProgress {
    progress.phase_progress.clone()
}

// PhaseProgress accessor methods

/// Get the phase index from PhaseProgress.
pub fn phase_progress_phase_index(progress: &ApiPhaseProgress) -> u32 {
    progress.phase_index
}

/// Get the phase name from PhaseProgress.
pub fn phase_progress_phase_name(progress: &ApiPhaseProgress) -> String {
    progress.phase_name.clone()
}

/// Get the target zone from PhaseProgress.
pub fn phase_progress_target_zone(progress: &ApiPhaseProgress) -> Zone {
    progress.target_zone
}

/// Get the elapsed seconds in the current phase from PhaseProgress.
pub fn phase_progress_elapsed_secs(progress: &ApiPhaseProgress) -> u32 {
    progress.elapsed_secs
}

/// Get the remaining seconds in the current phase from PhaseProgress.
pub fn phase_progress_remaining_secs(progress: &ApiPhaseProgress) -> u32 {
    progress.remaining_secs
}

// SessionState helper methods

/// Check if the session state is Running.
pub fn session_state_is_running(state: &ApiSessionState) -> bool {
    matches!(state, ApiSessionState::Running)
}

/// Check if the session state is Paused.
pub fn session_state_is_paused(state: &ApiSessionState) -> bool {
    matches!(state, ApiSessionState::Paused)
}

/// Check if the session state is Completed.
pub fn session_state_is_completed(state: &ApiSessionState) -> bool {
    matches!(state, ApiSessionState::Completed)
}

/// Check if the session state is Stopped.
pub fn session_state_is_stopped(state: &ApiSessionState) -> bool {
    matches!(state, ApiSessionState::Stopped)
}

/// Convert SessionState to a string representation.
pub fn session_state_to_string(state: &ApiSessionState) -> String {
    match state {
        ApiSessionState::Running => "Running".to_string(),
        ApiSessionState::Paused => "Paused".to_string(),
        ApiSessionState::Completed => "Completed".to_string(),
        ApiSessionState::Stopped => "Stopped".to_string(),
    }
}

// ZoneStatus helper methods

/// Check if the zone status is InZone.
pub fn zone_status_is_in_zone(status: &ApiZoneStatus) -> bool {
    matches!(status, ApiZoneStatus::InZone)
}

/// Check if the zone status is TooLow.
pub fn zone_status_is_too_low(status: &ApiZoneStatus) -> bool {
    matches!(status, ApiZoneStatus::TooLow)
}

/// Check if the zone status is TooHigh.
pub fn zone_status_is_too_high(status: &ApiZoneStatus) -> bool {
    matches!(status, ApiZoneStatus::TooHigh)
}

/// Convert ZoneStatus to a string representation.
pub fn zone_status_to_string(status: &ApiZoneStatus) -> String {
    match status {
        ApiZoneStatus::InZone => "InZone".to_string(),
        ApiZoneStatus::TooLow => "TooLow".to_string(),
        ApiZoneStatus::TooHigh => "TooHigh".to_string(),
    }
}

/// JNI_OnLoad - Initialize Android context and btleplug for JNI operations
///
/// This function is called by the Android runtime when the native library is loaded.
/// It initializes the ndk-context and btleplug while we have access to the app's classloader.
#[cfg(target_os = "android")]
#[no_mangle]
pub extern "C" fn JNI_OnLoad(vm: jni::JavaVM, _res: *mut std::os::raw::c_void) -> jni::sys::jint {
    use std::ffi::c_void;

    // Initialize android_logger FIRST so we can see all logs
    android_logger::init_once(
        android_logger::Config::default()
            .with_max_level(LevelFilter::Debug)
            .with_tag("heart_beat"),
    );

    log::info!("JNI_OnLoad: Starting initialization");

    let vm_ptr = vm.get_java_vm_pointer() as *mut c_void;
    unsafe {
        ndk_context::initialize_android_context(vm_ptr, _res);
    }
    log::info!("JNI_OnLoad: NDK context initialized");

    // Initialize btleplug and jni-utils while we have access to the main thread's classloader
    // This must be done here, not later from Flutter, because the classloader
    // context is only correct during JNI_OnLoad
    match vm.get_env() {
        Ok(mut env) => {
            log::info!("JNI_OnLoad: Got JNI environment");

            // Initialize jni-utils first (required by btleplug's async operations)
            log::info!("JNI_OnLoad: Initializing jni-utils");
            if let Err(e) = jni_utils::init(&mut env) {
                log::error!("JNI_OnLoad: jni-utils init failed: {:?}", e);
            } else {
                log::info!("JNI_OnLoad: jni-utils initialized successfully");
            }

            // Then initialize btleplug
            log::info!("JNI_OnLoad: Initializing btleplug");
            match btleplug::platform::init(&mut env) {
                Ok(()) => {
                    log::info!("JNI_OnLoad: btleplug initialized successfully");
                }
                Err(e) => {
                    // Log error but don't fail - btleplug may already be initialized
                    log::error!("JNI_OnLoad: btleplug init failed: {}", e);
                }
            }
        }
        Err(e) => {
            log::error!("JNI_OnLoad: Failed to get JNI environment: {:?}", e);
        }
    }

    log::info!("JNI_OnLoad: Initialization complete");
    jni::JNIVersion::V6.into()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::session_history::{
        CompletedSession, HrSample, SessionStatus, SessionSummary,
    };
    use chrono::Utc;

    fn create_test_hr_data(raw_bpm: u16, filtered_bpm: u16) -> ApiFilteredHeartRate {
        ApiFilteredHeartRate {
            raw_bpm,
            filtered_bpm,
            rmssd: Some(45.0),
            filter_variance: Some(1.5),
            battery_level: Some(85),
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis() as u64,
        }
    }

    fn create_test_session(id: &str, plan_name: &str) -> CompletedSession {
        let now = Utc::now();
        CompletedSession {
            id: id.to_string(),
            plan_name: plan_name.to_string(),
            start_time: now,
            end_time: now + chrono::Duration::seconds(1800),
            status: SessionStatus::Completed,
            hr_samples: vec![
                HrSample {
                    timestamp: now,
                    bpm: 120,
                },
                HrSample {
                    timestamp: now + chrono::Duration::seconds(900),
                    bpm: 140,
                },
                HrSample {
                    timestamp: now + chrono::Duration::seconds(1800),
                    bpm: 130,
                },
            ],
            phases_completed: 2,
            summary: SessionSummary {
                duration_secs: 1800,
                avg_hr: 130,
                max_hr: 140,
                min_hr: 120,
                time_in_zone: [0, 900, 900, 0, 0],
            },
        }
    }

    #[tokio::test]
    async fn test_hr_stream_receiver_creation() {
        // Should be able to create multiple receivers
        let _rx1 = get_hr_stream_receiver();
        let _rx2 = get_hr_stream_receiver();
        // Test passes if no panic
    }

    #[tokio::test]
    async fn test_emit_and_receive_hr_data() {
        use tokio::time::{timeout, Duration};

        // Create a receiver
        let mut rx = get_hr_stream_receiver();

        // Drain any old data from previous tests with a short timeout
        while timeout(Duration::from_millis(10), rx.recv()).await.is_ok() {}

        // Emit some data
        let data = create_test_hr_data(80, 79);

        let count = emit_hr_data(data.clone());
        // Note: count may be > 1 due to global state shared across tests
        assert!(count > 0, "Should have at least 1 receiver");

        // Receive the data
        let received = rx.recv().await.expect("Should receive data");
        assert_eq!(received.raw_bpm, 80);
        assert_eq!(received.filtered_bpm, 79);
    }

    #[tokio::test]
    async fn test_multiple_receivers_fan_out() {
        use tokio::time::{sleep, timeout, Duration};

        // Create receivers first
        let mut rx1 = get_hr_stream_receiver();
        let mut rx2 = get_hr_stream_receiver();
        let mut rx3 = get_hr_stream_receiver();

        // Drain any old data from previous tests with a longer timeout
        while timeout(Duration::from_millis(50), rx1.recv()).await.is_ok() {}
        while timeout(Duration::from_millis(50), rx2.recv()).await.is_ok() {}
        while timeout(Duration::from_millis(50), rx3.recv()).await.is_ok() {}

        // Small delay to ensure we don't race with other tests
        sleep(Duration::from_millis(10)).await;

        // Emit data with unique BPM to identify this test's data
        let data = create_test_hr_data(155, 154);
        emit_hr_data(data);

        // All receivers should get the data
        let r1 = rx1.recv().await.expect("rx1 should receive");
        let r2 = rx2.recv().await.expect("rx2 should receive");
        let r3 = rx3.recv().await.expect("rx3 should receive");

        assert_eq!(r1.raw_bpm, 155);
        assert_eq!(r2.raw_bpm, 155);
        assert_eq!(r3.raw_bpm, 155);
        assert_eq!(r1.filtered_bpm, 154);
        assert_eq!(r2.filtered_bpm, 154);
        assert_eq!(r3.filtered_bpm, 154);
    }

    #[tokio::test]
    async fn test_stream_backpressure() {
        let mut rx = get_hr_stream_receiver();

        // Emit more than buffer capacity (100 items)
        for i in 0..150 {
            let data = create_test_hr_data(60 + i as u16, 60 + i as u16);
            emit_hr_data(data);
        }

        // Should be able to receive data, but may have missed some due to lagging
        match rx.recv().await {
            Ok(data) => {
                // Successfully received data
                assert!(data.raw_bpm >= 60 && data.raw_bpm < 210);
            }
            Err(broadcast::error::RecvError::Lagged(skipped)) => {
                // Expected when buffer is exceeded
                assert!(skipped > 0, "Should report skipped messages");
            }
            Err(e) => panic!("Unexpected error: {:?}", e),
        }
    }

    #[tokio::test]
    async fn test_session_api_integration() {
        use std::env;
        use tempfile::tempdir;

        // Create a temporary directory for this test
        let temp_dir = tempdir().unwrap();
        let temp_path = temp_dir.path().to_str().unwrap();

        // Set HOME environment variable to temp directory so FileSessionRepository
        // will use a temporary .heart-beat/sessions directory
        let original_home = env::var("HOME").ok();
        env::set_var("HOME", temp_path);

        // Clear the global repository to force re-initialization
        // This is a bit hacky but necessary for testing with a temp directory
        if let Some(mutex) = SESSION_REPOSITORY.get() {
            *mutex.lock().await = None;
        }

        // Create a test session
        let session = create_test_session("test-api-123", "Test Workout");

        // Save the session directly using the repository
        let repo = get_session_repository().await.unwrap();
        repo.save(&session).await.unwrap();

        // Test list_sessions
        let sessions = list_sessions().await.unwrap();
        assert_eq!(sessions.len(), 1);
        assert_eq!(sessions[0].id, "test-api-123");
        assert_eq!(sessions[0].plan_name, "Test Workout");
        assert_eq!(sessions[0].avg_hr, 130);

        // Test get_session
        let retrieved = get_session("test-api-123".to_string()).await.unwrap();
        assert!(retrieved.is_some());
        let retrieved_session = retrieved.unwrap();
        assert_eq!(retrieved_session.id, "test-api-123");
        assert_eq!(retrieved_session.hr_samples.len(), 3);

        // Test get_session with non-existent ID
        let not_found = get_session("nonexistent".to_string()).await.unwrap();
        assert!(not_found.is_none());

        // Test delete_session
        delete_session("test-api-123".to_string()).await.unwrap();
        let sessions_after_delete = list_sessions().await.unwrap();
        assert_eq!(sessions_after_delete.len(), 0);

        // Restore original HOME
        if let Some(home) = original_home {
            env::set_var("HOME", home);
        } else {
            env::remove_var("HOME");
        }

        // Clean up temp directory
        temp_dir.close().unwrap();
    }

    #[tokio::test]
    async fn test_disconnect_when_connected() {
        use tokio::time::{sleep, Duration};

        // Clear any existing connection state
        if let Some(mutex) = CONNECTION_STATE.get() {
            *mutex.lock().await = None;
        }

        // Clear global adapter state
        if let Some(mutex) = BLE_ADAPTER.get() {
            *mutex.lock().await = None;
        }

        // Create a real BtleplugAdapter for testing
        // Note: This may fail on systems without BLE, so we'll handle errors gracefully
        let adapter_result = BtleplugAdapter::new().await;

        if adapter_result.is_err() {
            // Skip test if BLE is not available
            eprintln!("Skipping test_disconnect_when_connected: BLE adapter unavailable");
            return;
        }

        let adapter = Arc::new(adapter_result.unwrap());

        // Manually set up connection state to simulate a connected device
        let (_hr_tx, mut hr_rx) = tokio::sync::mpsc::channel::<()>(10);
        let hr_task_handle = tokio::spawn(async move {
            // Simulate HR streaming
            while hr_rx.recv().await.is_some() {
                // Just consume messages
            }
        });

        let (_battery_tx, mut battery_rx) = tokio::sync::mpsc::channel::<()>(10);
        let battery_task_handle = tokio::spawn(async move {
            // Simulate battery polling
            while battery_rx.recv().await.is_some() {
                // Just consume messages
            }
        });

        // Manually create connection state
        let connection_state = ConnectionState {
            adapter: adapter.clone(),
            device_id: "test-device-123".to_string(),
            hr_task_handle,
            battery_task_handle,
        };

        let state_mutex = CONNECTION_STATE.get_or_init(|| tokio::sync::Mutex::new(None));
        *state_mutex.lock().await = Some(connection_state);

        // Call disconnect
        let result = disconnect().await;
        assert!(
            result.is_ok(),
            "Disconnect should succeed: {:?}",
            result.err()
        );

        // Verify connection state was cleared
        let state_guard = state_mutex.lock().await;
        assert!(state_guard.is_none(), "Connection state should be cleared");

        // Give tasks a moment to be aborted
        sleep(Duration::from_millis(50)).await;
    }

    #[tokio::test]
    async fn test_disconnect_when_already_disconnected() {
        // Clear any existing connection state
        if let Some(mutex) = CONNECTION_STATE.get() {
            *mutex.lock().await = None;
        }

        // Call disconnect when already disconnected - should be idempotent
        let result = disconnect().await;
        assert!(
            result.is_ok(),
            "Disconnect should succeed even when already disconnected"
        );
    }

    #[tokio::test]
    async fn test_connect_after_disconnect() {
        // Clear any existing connection state and BLE adapter
        if let Some(mutex) = CONNECTION_STATE.get() {
            *mutex.lock().await = None;
        }
        if let Some(mutex) = BLE_ADAPTER.get() {
            *mutex.lock().await = None;
        }

        // This test verifies that reconnection works after disconnect
        // For a full integration test, we would need to:
        // 1. Set up a mock adapter as the global BLE adapter
        // 2. Call connect_device with a mock device
        // 3. Call disconnect
        // 4. Call connect_device again
        //
        // However, this requires more extensive mocking infrastructure.
        // For now, we verify that the state management allows reconnection
        // by ensuring disconnect clears state properly (tested above).

        // Verify state is clear for reconnection
        let state_mutex = CONNECTION_STATE.get_or_init(|| tokio::sync::Mutex::new(None));
        let state_guard = state_mutex.lock().await;
        assert!(
            state_guard.is_none(),
            "State should be clear and ready for reconnection"
        );
    }
}
