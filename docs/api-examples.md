# API Usage Examples

This document provides practical examples of using the Heart Beat library API. All examples are complete and runnable.

## Table of Contents

- [Scanning for Devices](#scanning-for-devices)
- [Connecting and Streaming Heart Rate](#connecting-and-streaming-heart-rate)
- [Running a Training Session](#running-a-training-session)
- [Using Mock Adapter for Testing](#using-mock-adapter-for-testing)
- [Creating Custom NotificationPort](#creating-custom-notificationport)
- [Common Patterns](#common-patterns)

---

## Scanning for Devices

The simplest use case: discover nearby heart rate monitors.

```rust
use heart_beat::adapters::btleplug_adapter::BtleplugAdapter;
use heart_beat::ports::ble_adapter::BleAdapter;
use std::time::Duration;
use tokio::time::sleep;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Create a BLE adapter instance
    let adapter = BtleplugAdapter::new().await?;

    // Start scanning for devices
    println!("Scanning for heart rate monitors...");
    adapter.start_scan().await?;

    // Scan for 10 seconds
    sleep(Duration::from_secs(10)).await;

    // Stop scan and retrieve results
    adapter.stop_scan().await?;
    let devices = adapter.get_discovered_devices().await;

    // Display discovered devices
    println!("\nFound {} device(s):", devices.len());
    for device in devices {
        println!(
            "  - {} (ID: {}, RSSI: {} dBm)",
            device.name.as_deref().unwrap_or("Unknown"),
            device.id,
            device.rssi.unwrap_or(0)
        );
    }

    Ok(())
}
```

**Key Points:**
- Always call `stop_scan()` before retrieving devices
- Scanning duration affects discovery completeness
- RSSI (signal strength) helps choose the nearest device
- Devices are filtered to only show HR Service (UUID 0x180D)

---

## Connecting and Streaming Heart Rate

Connect to a device and receive real-time heart rate data.

```rust
use heart_beat::adapters::btleplug_adapter::BtleplugAdapter;
use heart_beat::domain::filters::KalmanFilter;
use heart_beat::domain::heart_rate::parse_heart_rate;
use heart_beat::domain::hrv::calculate_rmssd;
use heart_beat::ports::ble_adapter::BleAdapter;
use std::collections::VecDeque;
use std::sync::Arc;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Create BLE adapter
    let adapter = Arc::new(BtleplugAdapter::new().await?);

    // Connect to device (replace with actual device ID from scan)
    let device_id = "AA:BB:CC:DD:EE:FF";
    println!("Connecting to {}...", device_id);
    adapter.connect(device_id).await?;
    println!("Connected!");

    // Subscribe to heart rate notifications
    let mut hr_receiver = adapter.subscribe_hr().await?;

    // Set up Kalman filter for smoothing
    let mut kalman = KalmanFilter::new();

    // Buffer for HRV calculation (needs 5+ RR intervals)
    let mut rr_intervals: VecDeque<u16> = VecDeque::new();

    // Process incoming heart rate data
    println!("\nReceiving heart rate data (Ctrl+C to stop)...\n");
    while let Some(packet) = hr_receiver.recv().await {
        // Parse BLE heart rate packet
        let hr_data = parse_heart_rate(&packet)?;

        // Apply Kalman filtering
        let filtered_bpm = kalman.update(hr_data.heart_rate as f64) as u16;

        // Calculate HRV if RR intervals available
        let mut rmssd = None;
        if let Some(rr) = hr_data.rr_interval {
            rr_intervals.push_back(rr);
            if rr_intervals.len() > 10 {
                rr_intervals.pop_front();
            }
            if rr_intervals.len() >= 5 {
                rmssd = calculate_rmssd(&rr_intervals.iter().copied().collect::<Vec<_>>());
            }
        }

        // Display current metrics
        print!("\r");
        print!("HR: {} bpm (filtered: {} bpm)", hr_data.heart_rate, filtered_bpm);
        if let Some(rmssd_val) = rmssd {
            print!(" | HRV (RMSSD): {:.1} ms", rmssd_val);
        }
        if let Some(battery) = hr_data.battery_level {
            print!(" | Battery: {}%", battery);
        }
        use std::io::Write;
        std::io::stdout().flush().unwrap();
    }

    // Disconnect when done
    adapter.disconnect().await?;
    println!("\nDisconnected.");

    Ok(())
}
```

**Key Points:**
- Use `Arc` to share adapter across tasks
- Parse raw BLE packets with `parse_heart_rate()`
- Kalman filter smooths noisy measurements
- HRV requires at least 5 RR intervals for accuracy
- RR intervals are in milliseconds between heartbeats

---

## Running a Training Session

Execute a structured workout with automatic phase transitions.

```rust
use heart_beat::adapters::btleplug_adapter::BtleplugAdapter;
use heart_beat::adapters::mock_notification_adapter::MockNotificationAdapter;
use heart_beat::domain::heart_rate::Zone;
use heart_beat::domain::training_plan::{TrainingPlan, TrainingPhase, TransitionCondition};
use heart_beat::ports::ble_adapter::BleAdapter;
use heart_beat::scheduler::SessionExecutor;
use chrono::Utc;
use std::sync::Arc;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Create a training plan
    let plan = TrainingPlan {
        name: "Easy Base Run".to_string(),
        max_hr: 180, // User's max heart rate
        created_at: Utc::now(),
        phases: vec![
            // Warmup: 5 minutes in Zone 2
            TrainingPhase {
                name: "Warmup".to_string(),
                target_zone: Zone::Zone2,
                duration_secs: 300,
                transition: TransitionCondition::TimeElapsed,
            },
            // Main: 20 minutes in Zone 3
            TrainingPhase {
                name: "Main Set".to_string(),
                target_zone: Zone::Zone3,
                duration_secs: 1200,
                transition: TransitionCondition::TimeElapsed,
            },
            // Cooldown: 5 minutes in Zone 2
            TrainingPhase {
                name: "Cooldown".to_string(),
                target_zone: Zone::Zone2,
                duration_secs: 300,
                transition: TransitionCondition::TimeElapsed,
            },
        ],
    };

    // Connect to device
    let adapter = Arc::new(BtleplugAdapter::new().await?);
    // ... perform scan and connect (see previous examples) ...

    // Create notification handler
    let notifier = Arc::new(MockNotificationAdapter::new());

    // Create session executor
    let mut executor = SessionExecutor::new(
        plan.clone(),
        adapter.clone(),
        notifier.clone(),
    );

    // Start the session
    println!("Starting workout: {}", plan.name);
    executor.start().await?;

    // Session runs in background, processing HR data and transitions
    // Wait for completion or handle pause/resume
    executor.wait_for_completion().await?;

    println!("Workout complete!");

    Ok(())
}
```

**Key Points:**
- `max_hr` should be personalized (220 - age is a rough estimate)
- Zone percentages: Z1 (50-60%), Z2 (60-70%), Z3 (70-80%), Z4 (80-90%), Z5 (90-100%)
- `TransitionCondition::TimeElapsed` moves to next phase after duration
- `TransitionCondition::HeartRateReached` waits for target HR to be held
- `SessionExecutor` handles phase transitions and zone monitoring automatically

---

## Using Mock Adapter for Testing

Develop and test without physical hardware.

```rust
use heart_beat::adapters::mock_adapter::{MockAdapter, MockConfig};
use heart_beat::domain::filters::KalmanFilter;
use heart_beat::domain::heart_rate::parse_heart_rate;
use heart_beat::ports::ble_adapter::BleAdapter;
use std::sync::Arc;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Configure simulated heart rate pattern
    let config = MockConfig {
        baseline_bpm: 140,      // Simulate moderate exercise
        noise_range: 8,         // +/- 8 bpm noise
        spike_probability: 0.1, // 10% chance of spike
        spike_magnitude: 25,    // 25 bpm spike
        update_rate: 1.0,       // 1 Hz updates
        battery_level: 75,      // 75% battery
    };

    // Create mock adapter
    let adapter = Arc::new(MockAdapter::with_config(config));

    // "Scan" for mock devices
    adapter.start_scan().await?;
    tokio::time::sleep(std::time::Duration::from_secs(2)).await;
    adapter.stop_scan().await?;

    let devices = adapter.get_discovered_devices().await;
    println!("Mock devices found: {:?}", devices);

    // Connect to first mock device
    if let Some(device) = devices.first() {
        adapter.connect(&device.id).await?;
        println!("Connected to mock device!");

        // Subscribe and receive simulated data
        let mut rx = adapter.subscribe_hr().await?;
        let mut kalman = KalmanFilter::new();

        println!("\nSimulated heart rate data:\n");
        for _ in 0..30 {
            if let Some(packet) = rx.recv().await {
                let hr = parse_heart_rate(&packet)?;
                let filtered = kalman.update(hr.heart_rate as f64) as u16;
                println!(
                    "Raw: {} bpm | Filtered: {} bpm | Battery: {}%",
                    hr.heart_rate,
                    filtered,
                    hr.battery_level.unwrap_or(0)
                );
            }
        }

        adapter.disconnect().await?;
    }

    Ok(())
}
```

**Key Points:**
- `MockConfig` allows fine-grained control over simulation
- Perfect for automated testing and UI development
- Same API as real adapter - swap implementations easily
- Use `spike_probability` to test filter robustness
- Mock adapter generates realistic BLE packets

---

## Creating Custom NotificationPort

Implement custom notification behavior for your use case.

```rust
use heart_beat::ports::notification::{NotificationPort, NotificationEvent};
use heart_beat::state::session::ZoneDeviation;
use async_trait::async_trait;
use anyhow::Result;
use std::fs::OpenOptions;
use std::io::Write;

/// Custom notifier that logs to file and plays audio
pub struct CustomNotifier {
    log_file: std::sync::Mutex<std::fs::File>,
}

impl CustomNotifier {
    pub fn new(log_path: &str) -> Result<Self> {
        let file = std::fs::File::create(log_path)?;
        Ok(Self {
            log_file: std::sync::Mutex::new(file),
        })
    }

    fn play_audio(&self, tone: &str) {
        // Implement audio playback (e.g., using rodio crate)
        println!("🔊 Playing tone: {}", tone);
    }

    fn log_event(&self, message: &str) -> Result<()> {
        let mut file = self.log_file.lock().unwrap();
        writeln!(file, "[{}] {}", chrono::Utc::now(), message)?;
        Ok(())
    }
}

#[async_trait]
impl NotificationPort for CustomNotifier {
    async fn notify(&self, event: NotificationEvent) -> Result<()> {
        match event {
            NotificationEvent::ZoneDeviation { deviation, current_bpm, target_zone } => {
                let msg = format!(
                    "Zone deviation: {:?} (current: {} bpm, target: {:?})",
                    deviation, current_bpm, target_zone
                );
                self.log_event(&msg)?;

                // Play different tones based on deviation
                match deviation {
                    ZoneDeviation::TooLow => {
                        self.play_audio("low_tone.wav");
                    }
                    ZoneDeviation::TooHigh => {
                        self.play_audio("high_tone.wav");
                    }
                    ZoneDeviation::BackInZone => {
                        self.play_audio("success_tone.wav");
                    }
                }
            }

            NotificationEvent::PhaseTransition { from_phase, to_phase, phase_name } => {
                let msg = format!(
                    "Phase transition: {} -> {} ({})",
                    from_phase, to_phase, phase_name
                );
                self.log_event(&msg)?;
                self.play_audio("transition_tone.wav");
                println!("▶ {}", phase_name);
            }

            NotificationEvent::BatteryLow { percentage } => {
                let msg = format!("Battery low: {}%", percentage);
                self.log_event(&msg)?;
                println!("🔋 Warning: Battery at {}%", percentage);
            }

            NotificationEvent::ConnectionLost => {
                self.log_event("Connection lost")?;
                println!("❌ Connection to device lost!");
            }

            NotificationEvent::WorkoutReady { plan_name } => {
                let msg = format!("Workout ready: {}", plan_name);
                self.log_event(&msg)?;
                println!("✓ Ready to start: {}", plan_name);
            }
        }

        Ok(())
    }
}

// Usage example
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let notifier = std::sync::Arc::new(
        CustomNotifier::new("workout_log.txt")?
    );

    // Use with SessionExecutor
    // let executor = SessionExecutor::new(plan, adapter, notifier);

    Ok(())
}
```

**Key Points:**
- Implement `NotificationPort` trait for custom behavior
- Use `#[async_trait]` macro for async trait implementation
- Handle each `NotificationEvent` variant appropriately
- Combine multiple notification methods (audio, visual, logging, haptic)
- Thread-safe implementations use `Mutex` or channels

---

## Common Patterns

### Pattern 1: Graceful Shutdown

```rust
use tokio::signal;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};

let running = Arc::new(AtomicBool::new(true));
let r = running.clone();

// Spawn signal handler
tokio::spawn(async move {
    signal::ctrl_c().await.expect("Failed to listen for Ctrl+C");
    r.store(false, Ordering::SeqCst);
});

// Main loop with shutdown check
while running.load(Ordering::SeqCst) {
    // Process data...
}

// Cleanup
adapter.disconnect().await?;
```

### Pattern 2: Zone Calculation

```rust
use heart_beat::domain::heart_rate::Zone;

fn calculate_zone(current_bpm: u16, max_hr: u16) -> Zone {
    let percentage = (current_bpm as f64 / max_hr as f64) * 100.0;

    match percentage {
        p if p < 60.0 => Zone::Zone1,  // Recovery (50-60%)
        p if p < 70.0 => Zone::Zone2,  // Aerobic base (60-70%)
        p if p < 80.0 => Zone::Zone3,  // Tempo (70-80%)
        p if p < 90.0 => Zone::Zone4,  // Threshold (80-90%)
        _ => Zone::Zone5,              // VO2 max (90-100%)
    }
}
```

### Pattern 3: Loading Training Plans from JSON

```rust
use heart_beat::domain::training_plan::TrainingPlan;
use std::fs;

fn load_plan(path: &str) -> anyhow::Result<TrainingPlan> {
    let json = fs::read_to_string(path)?;
    let plan: TrainingPlan = serde_json::from_str(&json)?;
    Ok(plan)
}

// Usage
let plan = load_plan("docs/plans/5k-training.json")?;
```

### Pattern 4: Real-time Data Display

```rust
use std::io::{self, Write};

// Use carriage return for in-place updates
print!("\rHR: {} bpm | Zone: {:?} | Time: {}s", bpm, zone, elapsed);
io::stdout().flush().unwrap();
```

### Pattern 5: Error Recovery with Retry

```rust
use std::time::Duration;
use tokio::time::sleep;
use heart_beat::ports::ble_adapter::BleAdapter;

async fn connect_with_retry(
    adapter: &impl BleAdapter,
    device_id: &str,
    max_attempts: u32,
) -> anyhow::Result<()> {
    for attempt in 1..=max_attempts {
        match adapter.connect(device_id).await {
            Ok(_) => return Ok(()),
            Err(e) if attempt < max_attempts => {
                eprintln!("Connection attempt {} failed: {}", attempt, e);
                eprintln!("Retrying in 2 seconds...");
                sleep(Duration::from_secs(2)).await;
            }
            Err(e) => return Err(e),
        }
    }
    unreachable!()
}
```

### Pattern 6: Using State Machine Directly

```rust
use heart_beat::state::{ConnectionStateMachine, ConnectionEvent};
use heart_beat::adapters::btleplug_adapter::BtleplugAdapter;
use std::sync::Arc;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let adapter = Arc::new(BtleplugAdapter::new().await?);
    let mut state_machine = ConnectionStateMachine::new(adapter.clone());

    // Drive state transitions manually
    state_machine.handle(ConnectionEvent::DeviceSelected {
        device_id: "device_id".to_string(),
    })?;

    adapter.connect("device_id").await?;
    state_machine.handle(ConnectionEvent::ConnectionSuccess)?;
    state_machine.handle(ConnectionEvent::ServicesDiscovered)?;

    println!("Current state: {:?}", state_machine.current_state());

    Ok(())
}
```

### Pattern 7: HeartRateReached Transition

```rust
use heart_beat::domain::training_plan::{TrainingPhase, TransitionCondition};
use heart_beat::domain::heart_rate::Zone;

// Create a phase that waits for HR to reach and hold target
let phase = TrainingPhase {
    name: "Build to Threshold".to_string(),
    target_zone: Zone::Zone4,
    duration_secs: 600, // Max 10 minutes
    transition: TransitionCondition::HeartRateReached {
        target_bpm: 165,    // Must reach 165 bpm
        hold_secs: 30,      // Hold for 30 seconds
    },
};
```

---

## Additional Resources

- [Architecture Documentation](architecture.md) - System design and module structure
- [Development Guide](development.md) - Setup and contribution workflow
- [Module READMEs](../rust/src/) - Detailed module documentation
- [Training Plan Templates](plans/) - Example workout plans

## Running Examples

All examples can be adapted to standalone binaries in the `examples/` directory:

```bash
# Run an example
cargo run --example basic_scan

# With verbose logging
RUST_LOG=debug cargo run --example stream_hr
```

For questions or issues, please refer to the project README or open an issue on GitHub.
