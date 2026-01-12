//! Flutter Rust Bridge API Layer
//!
//! This module provides the FFI boundary between Rust core logic and Flutter UI.
//! It orchestrates domain, state, and adapter components without containing business logic.

use crate::adapters::btleplug_adapter::BtleplugAdapter;
use crate::domain::heart_rate::{parse_heart_rate, DiscoveredDevice, FilteredHeartRate};
use crate::frb_generated::StreamSink;
use crate::ports::{BleAdapter, NotificationPort};
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

// Global state for HR data streaming
static HR_CHANNEL_CAPACITY: usize = 100;

// Global state for battery data streaming
static BATTERY_CHANNEL_CAPACITY: usize = 10;

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

            // Discover services
            state_machine.handle(ConnectionEvent::ServicesDiscovered)?;

            // Subscribe to HR notifications and start emitting data
            let mut hr_receiver = adapter
                .subscribe_hr()
                .await
                .map_err(|e| anyhow!("Failed to subscribe to HR: {}", e))?;

            tracing::info!("Subscribed to HR notifications, starting data stream");

            // Start battery polling
            let adapter_clone = adapter.clone();
            tokio::spawn(async move {
                let (battery_tx, mut battery_rx) = tokio::sync::mpsc::channel(10);
                let notification_port: Arc<dyn NotificationPort> = Arc::new(StubNotificationPort);

                // Start battery polling task
                let poll_result = adapter_clone
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

            // Spawn background task to receive and emit HR data
            tokio::spawn(async move {
                while let Some(data) = hr_receiver.recv().await {
                    tracing::debug!("Received {} bytes of HR data", data.len());

                    match parse_heart_rate(&data) {
                        Ok(measurement) => {
                            // Simple filtering: use raw BPM for now
                            // TODO: Implement proper Kalman filter
                            let filtered_bpm = measurement.bpm;

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

            Ok(())
        }
        Ok(Err(e)) => {
            // Connection failed
            state_machine.handle(ConnectionEvent::ConnectionFailed)?;
            Err(anyhow!("Connection failed: {}", e))
        }
        Err(_) => {
            // Timeout
            state_machine.handle(ConnectionEvent::ConnectionFailed)?;
            Err(anyhow!("Connection timeout after 15 seconds"))
        }
    }
}

/// Disconnect from the currently connected device.
///
/// Gracefully disconnects from the active BLE connection and transitions
/// the state machine back to Idle.
///
/// # Errors
///
/// Returns an error if disconnection fails or no device is connected.
pub async fn disconnect() -> Result<()> {
    // Note: In a real implementation, we would need to maintain a global
    // connection state or pass the adapter/state machine as context.
    // For now, this is a placeholder that assumes the caller manages state.
    Err(anyhow!(
        "Disconnect not yet implemented - requires global state management"
    ))
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

    fn create_test_hr_data(raw_bpm: u16, filtered_bpm: u16) -> ApiFilteredHeartRate {
        ApiFilteredHeartRate {
            raw_bpm,
            filtered_bpm,
            rmssd: Some(45.0),
            battery_level: Some(85),
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis() as u64,
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
}
