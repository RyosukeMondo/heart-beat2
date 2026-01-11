# Ports Module

## Purpose

Define **trait interfaces** (contracts) for external dependencies. Ports enable **dependency inversion** - domain code depends on abstractions, not concrete implementations.

## Key Traits

### BleAdapter (`ble_adapter.rs`)

Abstracts Bluetooth Low Energy operations for heart rate monitors.

```rust
#[async_trait]
pub trait BleAdapter: Send + Sync {
    async fn scan_devices(&self, duration: Duration) -> Result<Vec<DiscoveredDevice>>;
    async fn connect(&mut self, device_id: &str) -> Result<()>;
    async fn stream_heart_rate(&self) -> Result<Receiver<HeartRateMeasurement>>;
    async fn disconnect(&mut self) -> Result<()>;
}
```

**DiscoveredDevice**
```rust
pub struct DiscoveredDevice {
    pub id: String,
    pub name: String,
    pub rssi: i16,  // Signal strength
}
```

**Responsibilities:**
- Scan for BLE HR monitors
- Connect/disconnect to specific device
- Stream real-time HR measurements
- Handle connection errors and retries

**Implementations:**
- `BtleplugAdapter` (real BLE via btleplug)
- `MockAdapter` (simulated HR for testing)

### NotificationPort (`notification.rs`)

Abstracts user notifications (audio, vibration, visual alerts).

```rust
#[async_trait]
pub trait NotificationPort: Send + Sync {
    async fn notify_zone_deviation(&self, current: Zone, target: Zone);
    async fn notify_phase_change(&self, phase_name: &str);
    async fn notify_session_complete(&self, summary: SessionSummary);
    async fn notify_connection_lost(&self);
}
```

**Responsibilities:**
- Alert user when HR exits target zone
- Announce training phase transitions
- Notify session completion
- Handle connection errors

**Implementations:**
- `CliNotificationAdapter` (terminal output)
- `MockNotificationAdapter` (test capture)
- (Future) `AndroidNotificationAdapter` (vibration + audio)

## Design Pattern

### Hexagonal Architecture (Ports & Adapters)

```
Domain Logic
     ↓
  Depends on Port (trait)
     ↑
  Implemented by Adapter (concrete type)
     ↓
External System (BLE, OS notifications)
```

**Benefits:**
1. **Testability** - Inject mocks for fast, deterministic tests
2. **Platform independence** - Swap adapters without touching domain
3. **Flexibility** - Add new adapters (iOS, Web, etc.) easily
4. **Decoupling** - Domain never imports infrastructure crates

## Usage Examples

### Using BleAdapter

```rust
use heart_beat::ports::BleAdapter;
use heart_beat::adapters::BtleplugAdapter;

#[tokio::main]
async fn main() -> Result<()> {
    // Production: real BLE
    let mut adapter = BtleplugAdapter::new();

    // Scan for devices
    let devices = adapter.scan_devices(Duration::from_secs(5)).await?;
    println!("Found {} devices", devices.len());

    // Connect to first device
    if let Some(device) = devices.first() {
        adapter.connect(&device.id).await?;

        // Stream HR data
        let mut rx = adapter.stream_heart_rate().await?;
        while let Some(hr) = rx.recv().await {
            println!("HR: {} BPM", hr.bpm);
        }
    }

    Ok(())
}
```

### Testing with MockAdapter

```rust
use heart_beat::ports::BleAdapter;
use heart_beat::adapters::MockAdapter;

#[tokio::test]
async fn test_hr_processing() {
    // Test: simulated HR
    let mut adapter = MockAdapter::new();
    adapter.set_mock_hr(140); // Set steady 140 BPM

    adapter.connect("mock-device").await.unwrap();
    let mut rx = adapter.stream_heart_rate().await.unwrap();

    // Verify HR stream
    let hr = rx.recv().await.unwrap();
    assert_eq!(hr.bpm, 140);
}
```

### Using NotificationPort

```rust
use heart_beat::ports::NotificationPort;
use heart_beat::adapters::CliNotificationAdapter;
use heart_beat::domain::Zone;

#[tokio::main]
async fn main() -> Result<()> {
    let notifier = CliNotificationAdapter::new();

    // Notify zone deviation
    notifier.notify_zone_deviation(Zone::Z4, Zone::Z2).await;
    // Output: "⚠️ HR too high! Current: Z4, Target: Z2 - Slow down!"

    // Notify phase change
    notifier.notify_phase_change("Intervals").await;
    // Output: "🔔 Starting phase: Intervals"

    Ok(())
}
```

## Dependency Injection

Ports enable flexible composition via dependency injection:

```rust
use std::sync::Arc;

pub struct SessionExecutor {
    ble: Arc<dyn BleAdapter>,
    notifier: Arc<dyn NotificationPort>,
}

impl SessionExecutor {
    pub fn new(
        ble: Arc<dyn BleAdapter>,
        notifier: Arc<dyn NotificationPort>
    ) -> Self {
        Self { ble, notifier }
    }

    pub async fn run(&mut self) {
        // Use injected dependencies
        self.ble.connect("device-id").await.unwrap();
        self.notifier.notify_phase_change("Warmup").await;
    }
}

// Production
let executor = SessionExecutor::new(
    Arc::new(BtleplugAdapter::new()),
    Arc::new(AndroidNotificationAdapter::new())
);

// Testing
let executor = SessionExecutor::new(
    Arc::new(MockAdapter::new()),
    Arc::new(MockNotificationAdapter::new())
);
```

## Testing Approach

### Unit Tests - Use Mocks

```rust
#[tokio::test]
async fn test_session_execution() {
    let ble = Arc::new(MockAdapter::new());
    let notifier = Arc::new(MockNotificationAdapter::new());

    let mut executor = SessionExecutor::new(ble, notifier.clone());
    executor.run().await;

    // Verify notifications were sent
    assert_eq!(notifier.get_call_count(), 3);
}
```

### Integration Tests - Use Real Adapters

```rust
#[tokio::test]
#[ignore] // Requires physical HR monitor
async fn test_real_ble_connection() {
    let mut adapter = BtleplugAdapter::new();
    let devices = adapter.scan_devices(Duration::from_secs(10)).await.unwrap();
    assert!(!devices.is_empty(), "No BLE devices found");
}
```

## Adding New Ports

When adding a new external dependency:

### 1. Define the trait

```rust
// ports/gps_adapter.rs
#[async_trait]
pub trait GpsAdapter: Send + Sync {
    async fn get_location(&self) -> Result<GpsCoordinate>;
    async fn stream_location(&self) -> Result<Receiver<GpsCoordinate>>;
}

pub struct GpsCoordinate {
    pub latitude: f64,
    pub longitude: f64,
    pub altitude: f64,
    pub timestamp: SystemTime,
}
```

### 2. Create mock implementation

```rust
// adapters/mock_gps_adapter.rs
pub struct MockGpsAdapter {
    location: GpsCoordinate,
}

impl MockGpsAdapter {
    pub fn new() -> Self {
        Self {
            location: GpsCoordinate::default(),
        }
    }

    pub fn set_location(&mut self, loc: GpsCoordinate) {
        self.location = loc;
    }
}

#[async_trait]
impl GpsAdapter for MockGpsAdapter {
    async fn get_location(&self) -> Result<GpsCoordinate> {
        Ok(self.location.clone())
    }
}
```

### 3. Create production implementation

```rust
// adapters/android_gps_adapter.rs
pub struct AndroidGpsAdapter {
    // Platform-specific GPS handle
}

#[async_trait]
impl GpsAdapter for AndroidGpsAdapter {
    async fn get_location(&self) -> Result<GpsCoordinate> {
        // Call Android LocationManager
    }
}
```

### 4. Use dependency injection

```rust
pub struct SessionExecutor {
    gps: Arc<dyn GpsAdapter>,  // Add to dependencies
}
```

## Design Guidelines

### ✅ Good Port Design

```rust
#[async_trait]
pub trait DataStore: Send + Sync {
    async fn save_session(&self, session: Session) -> Result<()>;
    async fn load_sessions(&self) -> Result<Vec<Session>>;
}
```
- Clear, focused responsibilities
- Domain types in/out
- `Send + Sync` for multi-threading
- Returns `Result` for error handling

### ❌ Bad Port Design

```rust
#[async_trait]
pub trait DataStore {
    async fn execute_sql(&self, query: &str) -> Result<String>;  // Too low-level!
    async fn get_database_handle(&self) -> Database;  // Leaks impl details!
}
```
- Exposes implementation details
- Hard to mock
- Couples domain to infrastructure

## Main Functions

### BleAdapter
- `scan_devices(duration)` - Discover nearby HR monitors
- `connect(device_id)` - Establish BLE connection
- `stream_heart_rate()` - Get live HR channel
- `disconnect()` - Close connection

### NotificationPort
- `notify_zone_deviation(current, target)` - Alert zone mismatch
- `notify_phase_change(phase_name)` - Announce new phase
- `notify_session_complete(summary)` - Display results
- `notify_connection_lost()` - Handle disconnect

---

See [../adapters/README.md](../adapters/README.md) for concrete implementations.
