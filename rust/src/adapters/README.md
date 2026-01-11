# Adapters Module

## Purpose

**Concrete implementations** of port traits. Adapters handle external I/O and platform-specific operations, implementing the interfaces defined in `ports/`.

## Key Implementations

### BtleplugAdapter (`btleplug_adapter.rs`)

Real BLE adapter using the `btleplug` library for production heart rate monitoring.

**Implementation:**
```rust
pub struct BtleplugAdapter {
    manager: Manager,
    peripheral: Option<Peripheral>,
    hr_stream: Option<Receiver<HeartRateMeasurement>>,
}

#[async_trait]
impl BleAdapter for BtleplugAdapter {
    async fn scan_devices(&self, duration: Duration) -> Result<Vec<DiscoveredDevice>>;
    async fn connect(&mut self, device_id: &str) -> Result<()>;
    async fn stream_heart_rate(&self) -> Result<Receiver<HeartRateMeasurement>>;
    async fn disconnect(&mut self) -> Result<()>;
}
```

**Responsibilities:**
- Discover BLE devices via platform Bluetooth stack
- Connect to HR monitors using device ID
- Subscribe to HR service (0x180D) and characteristic (0x2A37)
- Parse BLE notifications into `HeartRateMeasurement`
- Handle connection errors and disconnections

**Platform Support:**
- Linux: BlueZ via D-Bus
- Android: Android Bluetooth API via JNI
- macOS/iOS: CoreBluetooth

**Usage:**
```rust
use heart_beat::adapters::BtleplugAdapter;

let mut adapter = BtleplugAdapter::new();

// Scan for devices
let devices = adapter.scan_devices(Duration::from_secs(5)).await?;
for device in &devices {
    println!("{}: {} (RSSI: {})", device.id, device.name, device.rssi);
}

// Connect to device
adapter.connect(&devices[0].id).await?;

// Stream HR data
let mut rx = adapter.stream_heart_rate().await?;
while let Some(hr) = rx.recv().await {
    println!("HR: {} BPM", hr.bpm);
}
```

### MockAdapter (`mock_adapter.rs`)

Simulated BLE adapter for testing and development without physical hardware.

**Implementation:**
```rust
pub struct MockAdapter {
    config: MockConfig,
    hr_stream: Option<Receiver<HeartRateMeasurement>>,
    is_connected: bool,
}

pub struct MockConfig {
    pub steady_bpm: Option<u8>,
    pub pattern: HRPattern,
    pub dropout_rate: f64,
    pub noise_level: f64,
}

pub enum HRPattern {
    Steady(u8),
    Interval { low: u8, high: u8, duration_sec: u32 },
    Ramp { start: u8, end: u8, duration_sec: u32 },
    Realistic { base: u8, variability: u8 },
}
```

**Capabilities:**
- Simulate steady HR (e.g., 140 BPM)
- Generate interval patterns (120 → 165 → 120)
- Ramp patterns (warmup/cooldown simulation)
- Realistic variability (Gaussian noise)
- Simulate connection dropouts
- Configurable noise levels

**Usage:**
```rust
use heart_beat::adapters::{MockAdapter, MockConfig, HRPattern};

// Steady HR
let config = MockConfig {
    steady_bpm: Some(140),
    pattern: HRPattern::Steady(140),
    dropout_rate: 0.0,
    noise_level: 2.0,
};
let mut adapter = MockAdapter::with_config(config);

// Interval workout
let config = MockConfig {
    pattern: HRPattern::Interval {
        low: 120,
        high: 165,
        duration_sec: 60,
    },
    dropout_rate: 0.05, // 5% packet loss
    noise_level: 3.0,
    ..Default::default()
};
let adapter = MockAdapter::with_config(config);
```

### CliNotificationAdapter (`cli_notification_adapter.rs`)

Terminal-based notification adapter for CLI development tool.

**Implementation:**
```rust
pub struct CliNotificationAdapter {
    use_color: bool,
    use_emoji: bool,
}

#[async_trait]
impl NotificationPort for CliNotificationAdapter {
    async fn notify_zone_deviation(&self, current: Zone, target: Zone);
    async fn notify_phase_change(&self, phase_name: &str);
    async fn notify_session_complete(&self, summary: SessionSummary);
    async fn notify_connection_lost(&self);
}
```

**Features:**
- Color-coded output (zone warnings in red/yellow/green)
- Emoji indicators (⚠️ 🔔 ✅)
- Formatted tables for session summaries
- Auto-detects terminal capabilities

**Output Examples:**
```
⚠️  HR too high! Current: Z4 (165 BPM), Target: Z2 (120-140) - Slow down!
🔔 Starting phase: Intervals - Zone 4 (144-162 BPM)
✅ Session complete! Avg HR: 142.3 BPM, Time in zone: 87%
```

**Usage:**
```rust
use heart_beat::adapters::CliNotificationAdapter;

let notifier = CliNotificationAdapter::new()
    .with_color(true)
    .with_emoji(true);

notifier.notify_zone_deviation(Zone::Z4, Zone::Z2).await;
notifier.notify_phase_change("Warmup").await;
```

### MockNotificationAdapter (`mock_notification_adapter.rs`)

Test notification adapter that captures calls for verification.

**Implementation:**
```rust
pub struct MockNotificationAdapter {
    calls: Arc<Mutex<Vec<NotificationCall>>>,
}

pub enum NotificationCall {
    ZoneDeviation { current: Zone, target: Zone },
    PhaseChange { phase_name: String },
    SessionComplete { summary: SessionSummary },
    ConnectionLost,
}
```

**Testing Features:**
- Records all notification calls
- Queryable call history
- Call count tracking
- Verification helpers

**Usage:**
```rust
use heart_beat::adapters::MockNotificationAdapter;

#[tokio::test]
async fn test_notifications() {
    let notifier = Arc::new(MockNotificationAdapter::new());

    // Use in session
    let executor = SessionExecutor::new(plan, ble, notifier.clone());
    executor.start_session().await?;

    // Verify notifications
    assert_eq!(notifier.get_call_count(), 5);

    let calls = notifier.get_calls();
    assert!(matches!(
        calls[0],
        NotificationCall::PhaseChange { phase_name } if phase_name == "Warmup"
    ));
}
```

## Main Functions

### BtleplugAdapter

**Creation:**
```rust
BtleplugAdapter::new() -> Self
```

**BLE Operations:**
```rust
scan_devices(duration: Duration) -> Result<Vec<DiscoveredDevice>>
connect(device_id: &str) -> Result<()>
stream_heart_rate() -> Result<Receiver<HeartRateMeasurement>>
disconnect() -> Result<()>
```

### MockAdapter

**Creation:**
```rust
MockAdapter::new() -> Self
MockAdapter::with_config(config: MockConfig) -> Self
```

**Configuration:**
```rust
set_mock_hr(bpm: u8)
set_pattern(pattern: HRPattern)
set_dropout_rate(rate: f64)
set_noise_level(level: f64)
```

### CliNotificationAdapter

**Creation:**
```rust
CliNotificationAdapter::new() -> Self
```

**Configuration:**
```rust
with_color(enabled: bool) -> Self
with_emoji(enabled: bool) -> Self
```

### MockNotificationAdapter

**Creation:**
```rust
MockNotificationAdapter::new() -> Self
```

**Verification:**
```rust
get_call_count() -> usize
get_calls() -> Vec<NotificationCall>
clear_calls()
assert_called_times(n: usize)
```

## Usage Examples

### Development with CLI Adapter

```rust
use heart_beat::adapters::{MockAdapter, CliNotificationAdapter};
use heart_beat::scheduler::SessionExecutor;

#[tokio::main]
async fn main() -> Result<()> {
    let plan = TrainingPlan::from_json(&json)?;

    // Mock BLE, real CLI output
    let ble = Arc::new(MockAdapter::new());
    let notifier = Arc::new(CliNotificationAdapter::new());

    let mut executor = SessionExecutor::new(plan, ble, notifier);
    executor.start_session().await?;

    Ok(())
}
```

### Production with Real BLE

```rust
use heart_beat::adapters::{BtleplugAdapter, AndroidNotificationAdapter};

#[tokio::main]
async fn main() -> Result<()> {
    let plan = load_plan()?;

    // Real BLE, real Android notifications
    let ble = Arc::new(BtleplugAdapter::new());
    let notifier = Arc::new(AndroidNotificationAdapter::new());

    let mut executor = SessionExecutor::new(plan, ble, notifier);
    executor.start_session().await?;

    Ok(())
}
```

### Testing with Mocks

```rust
use heart_beat::adapters::{MockAdapter, MockNotificationAdapter};

#[tokio::test]
async fn test_zone_deviation_triggers_notification() {
    let plan = create_plan_with_zone2();

    let mut mock_ble = MockAdapter::new();
    mock_ble.set_mock_hr(165); // Simulate high HR (Zone 4)

    let notifier = Arc::new(MockNotificationAdapter::new());

    let ble = Arc::new(mock_ble);
    let mut executor = SessionExecutor::new(plan, ble, notifier.clone());

    executor.start_session().await.unwrap();

    // Verify zone deviation notification was sent
    let calls = notifier.get_calls();
    assert!(calls.iter().any(|c| matches!(
        c,
        NotificationCall::ZoneDeviation { current: Zone::Z4, target: Zone::Z2 }
    )));
}
```

### Simulating Realistic HR Patterns

```rust
use heart_beat::adapters::{MockAdapter, HRPattern};

// Interval workout: 2 min easy, 1 min hard, repeat
let pattern = HRPattern::Interval {
    low: 120,
    high: 165,
    duration_sec: 60,
};

let mut adapter = MockAdapter::with_config(MockConfig {
    pattern,
    noise_level: 3.0, // ±3 BPM jitter
    dropout_rate: 0.02, // 2% packet loss
    ..Default::default()
});

adapter.connect("mock-device").await?;
let mut rx = adapter.stream_heart_rate().await?;

for _ in 0..180 {
    let hr = rx.recv().await.unwrap();
    println!("HR: {} BPM", hr.bpm);
    tokio::time::sleep(Duration::from_secs(1)).await;
}
```

## Testing Approach

### Unit Tests - Adapter Logic

```rust
#[test]
fn test_mock_adapter_steady_hr() {
    let adapter = MockAdapter::new();
    adapter.set_mock_hr(140);

    // Verify steady HR generation
    for _ in 0..10 {
        let hr = adapter.generate_hr();
        assert!(hr >= 137 && hr <= 143); // Within noise range
    }
}

#[test]
fn test_cli_notification_formatting() {
    let notifier = CliNotificationAdapter::new();
    let output = notifier.format_zone_alert(Zone::Z4, Zone::Z2);

    assert!(output.contains("Z4"));
    assert!(output.contains("Z2"));
}
```

### Integration Tests - Real BLE (Requires Hardware)

```rust
#[tokio::test]
#[ignore] // Requires physical HR monitor
async fn test_btleplug_scan() {
    let adapter = BtleplugAdapter::new();
    let devices = adapter.scan_devices(Duration::from_secs(10)).await.unwrap();

    // Verify at least one HR monitor found
    assert!(!devices.is_empty());

    // Verify device has valid properties
    let device = &devices[0];
    assert!(!device.id.is_empty());
    assert!(!device.name.is_empty());
}

#[tokio::test]
#[ignore]
async fn test_btleplug_connection() {
    let mut adapter = BtleplugAdapter::new();
    let devices = adapter.scan_devices(Duration::from_secs(5)).await.unwrap();

    adapter.connect(&devices[0].id).await.unwrap();

    let mut rx = adapter.stream_heart_rate().await.unwrap();
    let hr = rx.recv().await.unwrap();

    assert!(hr.bpm >= 30 && hr.bpm <= 220);
}
```

## Error Handling

### BLE Connection Errors

```rust
use heart_beat::adapters::BtleplugAdapter;

match adapter.connect(device_id).await {
    Ok(_) => println!("Connected"),
    Err(e) if e.to_string().contains("timeout") => {
        println!("Connection timeout - device may be off");
    }
    Err(e) if e.to_string().contains("not found") => {
        println!("Device not found - check device ID");
    }
    Err(e) => println!("Connection error: {}", e),
}
```

### Stream Errors

```rust
let mut rx = adapter.stream_heart_rate().await?;

loop {
    match rx.recv().await {
        Some(hr) => process_hr(hr),
        None => {
            println!("HR stream ended - device disconnected");
            break;
        }
    }
}
```

## Design Guidelines

### ✅ Good Adapter Design

```rust
pub struct PlatformAdapter {
    // Hide platform-specific details
    handle: PlatformHandle,
}

impl PlatformAdapter {
    // Platform-agnostic constructor
    pub fn new() -> Self {
        #[cfg(target_os = "linux")]
        let handle = LinuxHandle::new();

        #[cfg(target_os = "android")]
        let handle = AndroidHandle::new();

        Self { handle }
    }
}

#[async_trait]
impl BleAdapter for PlatformAdapter {
    // Implement port trait
    async fn scan_devices(&self, duration: Duration) -> Result<Vec<DiscoveredDevice>> {
        // Delegate to platform-specific code
        self.handle.scan(duration).await
    }
}
```

**Good practices:**
- Encapsulate platform details
- Implement port traits faithfully
- Return domain types (not library types)
- Handle errors gracefully

### ❌ Bad Adapter Design

```rust
pub struct BadAdapter {
    pub raw_handle: btleplug::Manager, // Leaks implementation!
}

impl BadAdapter {
    pub fn do_scan(&self) -> btleplug::ScanResult { // Wrong return type!
        // Direct btleplug call - no abstraction
    }
}
```

**Avoid:**
- Exposing library types in public API
- Returning non-domain types
- Leaking implementation details

## Adding New Adapters

### Example: Add iOS BLE Adapter

1. **Create adapter file:**
```rust
// adapters/ios_ble_adapter.rs
pub struct IOSBleAdapter {
    // CoreBluetooth handles
}

#[async_trait]
impl BleAdapter for IOSBleAdapter {
    async fn scan_devices(&self, duration: Duration) -> Result<Vec<DiscoveredDevice>> {
        // Use CoreBluetooth via objc
    }
}
```

2. **Add to module:**
```rust
// adapters/mod.rs
#[cfg(target_os = "ios")]
pub mod ios_ble_adapter;

#[cfg(target_os = "ios")]
pub use ios_ble_adapter::IOSBleAdapter;
```

3. **Write tests:**
```rust
#[tokio::test]
#[cfg(target_os = "ios")]
async fn test_ios_scan() {
    let adapter = IOSBleAdapter::new();
    let devices = adapter.scan_devices(Duration::from_secs(5)).await.unwrap();
    assert!(!devices.is_empty());
}
```

---

See [../ports/README.md](../ports/README.md) for the trait interfaces these adapters implement.
