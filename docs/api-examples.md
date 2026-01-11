# API Usage Examples

This document provides complete, runnable code examples demonstrating common usage patterns of the Heart Beat library.

## Table of Contents

1. [Scanning for Devices](#scanning-for-devices)
2. [Connecting and Streaming HR](#connecting-and-streaming-hr)
3. [Running a Training Session](#running-a-training-session)
4. [Using Mock Adapter for Testing](#using-mock-adapter-for-testing)
5. [Creating Custom NotificationPort](#creating-custom-notificationport)
6. [Common Patterns](#common-patterns)

---

## Scanning for Devices

Scan for BLE heart rate monitors and display discovered devices:

```rust
use heart_beat::api::scan_devices;
use anyhow::Result;

#[tokio::main]
async fn main() -> Result<()> {
    println!("Scanning for heart rate monitors...");

    let devices = scan_devices().await?;

    if devices.is_empty() {
        println!("No devices found. Make sure your HR monitor is on and advertising.");
        return Ok(());
    }

    println!("Found {} device(s):", devices.len());
    for device in devices {
        println!("  - {} ({})", device.name, device.id);
        if let Some(rssi) = device.rssi {
            println!("    Signal strength: {} dBm", rssi);
        }
    }

    Ok(())
}
```

---

## Connecting and Streaming HR

Connect to a device and stream real-time heart rate data:

```rust
use heart_beat::api::{connect_device, stream_heart_rate};
use heart_beat::domain::heart_rate::FilteredHeartRate;
use tokio::sync::broadcast;
use anyhow::Result;

#[tokio::main]
async fn main() -> Result<()> {
    let device_id = "YOUR_DEVICE_ID"; // From scan results

    // Connect to device
    println!("Connecting to {}...", device_id);
    connect_device(device_id.to_string()).await?;
    println!("Connected!");

    // Create broadcast channel for HR data
    let (tx, mut rx) = broadcast::channel::<FilteredHeartRate>(100);

    // Start streaming in background
    tokio::spawn(async move {
        if let Err(e) = stream_heart_rate(device_id.to_string(), tx).await {
            eprintln!("Stream error: {}", e);
        }
    });

    // Display incoming HR data
    println!("Receiving heart rate data (Ctrl+C to stop):");
    while let Ok(hr_data) = rx.recv().await {
        println!(
            "{} BPM - Zone: {:?} - Quality: {:.1}%",
            hr_data.bpm,
            hr_data.zone,
            hr_data.quality * 100.0
        );
    }

    Ok(())
}
```

---

## Running a Training Session

Execute a structured training plan with phase transitions:

```rust
use heart_beat::domain::training_plan::{TrainingPlan, TrainingPhase, TransitionCondition};
use heart_beat::domain::heart_rate::Zone;
use heart_beat::scheduler::SessionExecutor;
use heart_beat::adapters::cli_notification_adapter::CliNotificationAdapter;
use chrono::Utc;
use std::sync::Arc;
use tokio::sync::broadcast;
use anyhow::Result;

#[tokio::main]
async fn main() -> Result<()> {
    // Create a training plan
    let plan = TrainingPlan {
        name: "Interval Workout".to_string(),
        created_at: Utc::now(),
        max_hr: 180,
        phases: vec![
            TrainingPhase {
                name: "Warmup".to_string(),
                target_zone: Zone::Zone2,
                duration_secs: 600, // 10 minutes
                transition: TransitionCondition::TimeElapsed,
            },
            TrainingPhase {
                name: "Work Interval".to_string(),
                target_zone: Zone::Zone4,
                duration_secs: 300, // 5 minutes
                transition: TransitionCondition::TimeElapsed,
            },
            TrainingPhase {
                name: "Recovery".to_string(),
                target_zone: Zone::Zone2,
                duration_secs: 300, // 5 minutes
                transition: TransitionCondition::TimeElapsed,
            },
            TrainingPhase {
                name: "Cooldown".to_string(),
                target_zone: Zone::Zone1,
                duration_secs: 600, // 10 minutes
                transition: TransitionCondition::TimeElapsed,
            },
        ],
    };

    // Create notification adapter (CLI-based for this example)
    let notifier = Arc::new(CliNotificationAdapter::new());

    // Create session executor
    let mut executor = SessionExecutor::new(notifier);

    // Optional: Create HR data channel for zone monitoring
    let (tx, rx) = broadcast::channel(100);
    executor.attach_hr_stream(rx);

    // Start the session
    println!("Starting session: {}", plan.name);
    executor.start_session(plan).await?;

    // Session runs in background, updating phase transitions automatically
    // To stop manually:
    // executor.stop_session().await?;

    // Wait for session to complete
    tokio::signal::ctrl_c().await?;
    executor.stop_session().await?;

    println!("Session completed!");
    Ok(())
}
```

---

## Using Mock Adapter for Testing

Use the mock BLE adapter to simulate heart rate data without physical hardware:

```rust
use heart_beat::adapters::mock_adapter::MockAdapter;
use heart_beat::ports::BleAdapter;
use heart_beat::state::{ConnectionStateMachine, ConnectionEvent};
use std::sync::Arc;
use anyhow::Result;

#[tokio::main]
async fn main() -> Result<()> {
    // Create mock adapter with steady HR pattern
    let mock = Arc::new(MockAdapter::new());

    // Configure mock to simulate a device
    mock.add_mock_device(
        "MOCK_POLAR_H10".to_string(),
        "Polar H10".to_string(),
    );

    // Create state machine with mock adapter
    let mut state_machine = ConnectionStateMachine::new(mock.clone());

    // Scan for devices
    mock.start_scan().await?;
    tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
    let devices = mock.get_discovered_devices().await;

    println!("Mock devices found: {}", devices.len());
    for device in &devices {
        println!("  - {}", device.name);
    }

    // Connect to mock device
    let device_id = devices[0].id.clone();
    state_machine.handle(ConnectionEvent::DeviceSelected {
        device_id: device_id.clone(),
    })?;

    mock.connect(&device_id).await?;
    state_machine.handle(ConnectionEvent::ConnectionSuccess)?;
    state_machine.handle(ConnectionEvent::ServicesDiscovered)?;

    // Start receiving heart rate notifications
    let mut rx = mock.start_notify(&device_id).await?;

    println!("Receiving mock HR data:");
    for _ in 0..10 {
        if let Ok(raw_hr) = rx.recv().await {
            println!("  {} BPM", raw_hr.bpm);
        }
    }

    // Disconnect
    mock.disconnect().await?;
    state_machine.handle(ConnectionEvent::Disconnected)?;

    println!("Mock test completed!");
    Ok(())
}
```

---

## Creating Custom NotificationPort

Implement a custom notification adapter for your platform:

```rust
use heart_beat::ports::notification::{NotificationPort, NotificationEvent};
use async_trait::async_trait;
use anyhow::Result;

/// Custom notification adapter that logs to a file
pub struct FileNotificationAdapter {
    log_file: std::path::PathBuf,
}

impl FileNotificationAdapter {
    pub fn new(log_file: std::path::PathBuf) -> Self {
        Self { log_file }
    }
}

#[async_trait]
impl NotificationPort for FileNotificationAdapter {
    async fn notify(&self, event: NotificationEvent) -> Result<()> {
        use std::fs::OpenOptions;
        use std::io::Write;

        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.log_file)?;

        let message = match event {
            NotificationEvent::SessionStarted { plan_name } => {
                format!("[SESSION] Started: {}", plan_name)
            }
            NotificationEvent::PhaseTransition {
                from_phase,
                to_phase,
                ..
            } => {
                format!("[PHASE] {} -> {}", from_phase, to_phase)
            }
            NotificationEvent::ZoneDeviation { current_zone, target_zone, .. } => {
                format!("[ALERT] Zone deviation: {:?} -> {:?}", current_zone, target_zone)
            }
            NotificationEvent::SessionCompleted { .. } => {
                "[SESSION] Completed".to_string()
            }
        };

        writeln!(file, "{}: {}", chrono::Utc::now(), message)?;
        Ok(())
    }
}

// Usage example
#[tokio::main]
async fn main() -> Result<()> {
    use std::sync::Arc;
    use heart_beat::scheduler::SessionExecutor;

    let log_path = std::path::PathBuf::from("session_log.txt");
    let notifier = Arc::new(FileNotificationAdapter::new(log_path));

    let executor = SessionExecutor::new(notifier);

    // Use executor with your custom notification adapter
    println!("Executor created with file notification adapter");

    Ok(())
}
```

---

## Common Patterns

### Pattern: Graceful Shutdown

Handle SIGTERM/SIGINT signals to cleanly stop sessions:

```rust
use tokio::signal;
use anyhow::Result;

async fn graceful_shutdown(mut executor: SessionExecutor) -> Result<()> {
    tokio::select! {
        _ = signal::ctrl_c() => {
            println!("Shutdown signal received, stopping session...");
            executor.stop_session().await?;
        }
    }
    Ok(())
}
```

### Pattern: HR Data Filtering

Filter HR data before processing:

```rust
use heart_beat::domain::heart_rate::FilteredHeartRate;
use tokio::sync::broadcast;

async fn filter_and_display(mut rx: broadcast::Receiver<FilteredHeartRate>) {
    while let Ok(hr) = rx.recv().await {
        // Only display high-quality readings
        if hr.quality > 0.8 {
            println!("{} BPM (quality: {:.0}%)", hr.bpm, hr.quality * 100.0);
        }
    }
}
```

### Pattern: Session with Persistence

Enable session checkpointing for crash recovery:

```rust
use heart_beat::scheduler::SessionExecutor;
use std::path::PathBuf;
use std::sync::Arc;
use anyhow::Result;

async fn create_persistent_session(
    notifier: Arc<dyn NotificationPort>
) -> Result<SessionExecutor> {
    let checkpoint_path = PathBuf::from("/var/lib/heartbeat/session.json");
    let executor = SessionExecutor::with_persistence(
        notifier,
        checkpoint_path
    ).await?;

    Ok(executor)
}
```

### Pattern: Multiple Device Scanning

Scan with custom timeout and filtering:

```rust
use heart_beat::adapters::btleplug_adapter::BtleplugAdapter;
use heart_beat::ports::BleAdapter;
use tokio::time::Duration;
use anyhow::Result;

async fn scan_with_timeout(timeout_secs: u64) -> Result<Vec<DiscoveredDevice>> {
    let adapter = BtleplugAdapter::new().await?;

    adapter.start_scan().await?;
    tokio::time::sleep(Duration::from_secs(timeout_secs)).await;
    adapter.stop_scan().await?;

    let devices = adapter.get_discovered_devices().await;

    // Filter devices by signal strength
    let strong_devices: Vec<_> = devices
        .into_iter()
        .filter(|d| d.rssi.unwrap_or(-100) > -70) // Strong signal only
        .collect();

    Ok(strong_devices)
}
```

### Pattern: Scheduled Workouts

Schedule workouts using cron expressions:

```rust
use heart_beat::scheduler::SessionExecutor;
use heart_beat::domain::training_plan::TrainingPlan;
use anyhow::Result;

async fn schedule_daily_workout(
    executor: &mut SessionExecutor,
    plan: TrainingPlan,
) -> Result<()> {
    // Schedule for 6:00 AM daily
    executor.schedule_session(plan, "0 0 6 * * *").await?;

    println!("Workout scheduled for 6:00 AM daily");
    Ok(())
}
```

---

## Error Handling Best Practices

Always handle errors gracefully:

```rust
use anyhow::{Context, Result};

async fn robust_connection(device_id: &str) -> Result<()> {
    heart_beat::api::connect_device(device_id.to_string())
        .await
        .context("Failed to connect to device")?;

    Ok(())
}

// Usage
match robust_connection("device_123").await {
    Ok(_) => println!("Connected successfully"),
    Err(e) => eprintln!("Connection error: {:#}", e),
}
```

---

## Testing Recommendations

1. **Use MockAdapter for unit tests** - No hardware required
2. **Test with steady HR patterns first** - Validate zone calculations
3. **Simulate dropout scenarios** - Ensure reconnection logic works
4. **Test phase transitions** - Verify state machine correctness
5. **Enable persistence in integration tests** - Test crash recovery

For complete integration tests, see `rust/tests/` directory.
