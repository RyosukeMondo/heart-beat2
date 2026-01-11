# Heart Beat Examples

This directory contains standalone examples demonstrating how to use the Heart Beat library for various common use cases.

## Available Examples

### 1. Basic Scan (`basic_scan.rs`)

Demonstrates how to scan for Bluetooth Low Energy heart rate monitors.

**Run:**
```bash
cargo run --example basic_scan
```

**What it shows:**
- Initializing the BLE adapter
- Starting a scan for devices
- Listing discovered devices with their IDs and names
- Using the mock adapter for testing

**Key concepts:**
- `BleAdapter` trait
- `MockAdapter` for hardware-free testing
- Async device discovery

---

### 2. Stream Heart Rate (`stream_hr.rs`)

Shows the complete workflow for connecting to a heart rate monitor and streaming live data.

**Run:**
```bash
cargo run --example stream_hr
```

**What it shows:**
- Scanning and selecting a device
- Establishing a BLE connection
- Subscribing to heart rate notifications
- Parsing raw BLE packets
- Filtering data with Kalman filter
- Calculating HRV (RMSSD) from RR-intervals
- Displaying formatted output with battery level

**Key concepts:**
- Complete pipeline: scan → connect → subscribe → parse → filter → display
- `parse_heart_rate()` for packet decoding
- `KalmanFilter` for signal smoothing
- `calculate_rmssd()` for HRV analysis
- `FilteredHeartRate` output struct

---

### 3. Mock Training Session (`mock_session.rs`)

Demonstrates running a complete training session with phase transitions and zone monitoring.

**Run:**
```bash
cargo run --example mock_session
```

**What it shows:**
- Creating a `TrainingPlan` with multiple phases
- Simulating a workout session
- Calculating heart rate zones
- Detecting zone violations
- Phase transitions
- Session statistics and compliance tracking

**Key concepts:**
- `TrainingPlan` and `TrainingPhase` structures
- `calculate_zone()` for zone determination
- `TransitionCondition` for phase control
- Training compliance monitoring
- Mock adapter for predictable testing

---

### 4. Custom Notification Handler (`custom_notifier.rs`)

Shows how to implement custom notification handlers by implementing the `NotificationPort` trait.

**Run:**
```bash
cargo run --example custom_notifier
```

**What it shows:**
- Implementing `NotificationPort` trait
- File-based notification logging
- Console output formatting
- In-memory notification collection
- Handling different notification event types
- Pattern matching on `NotificationEvent`

**Key concepts:**
- `NotificationPort` trait abstraction
- `NotificationEvent` enum variants
- `#[async_trait]` for async methods
- Custom notification strategies
- Testing with notification collectors

---

## Running Examples

All examples are designed to run standalone without requiring physical hardware:

```bash
# From the rust/ directory
cargo run --example <example_name>
```

For example:
```bash
cargo run --example basic_scan
cargo run --example stream_hr
cargo run --example mock_session
cargo run --example custom_notifier
```

## Using with Real Hardware

To use real Bluetooth hardware instead of the mock adapter, replace:

```rust
use heart_beat::adapters::mock_adapter::{MockAdapter, MockConfig};
let adapter = MockAdapter::with_config(config);
```

With:

```rust
use heart_beat::adapters::btleplug_adapter::BtleplugAdapter;
let adapter = BtleplugAdapter::new().await?;
```

**Note:** Real hardware requires:
- Bluetooth adapter on your system
- Proper permissions (may need `sudo` on Linux)
- A compatible heart rate monitor device

## Example Dependencies

All examples use these common dependencies:
- `tokio` - Async runtime
- `anyhow` - Error handling
- `tracing` / `tracing-subscriber` - Logging
- `chrono` - Timestamps

These are already included in the project's `Cargo.toml`.

## Learning Path

Recommended order for learning the library:

1. **basic_scan.rs** - Start here to understand BLE device discovery
2. **stream_hr.rs** - Learn the full data pipeline
3. **mock_session.rs** - Understand training plans and sessions
4. **custom_notifier.rs** - Explore extensibility with custom handlers

## Common Patterns

### Error Handling

All examples use `anyhow::Result` for clean error propagation:

```rust
async fn main() -> anyhow::Result<()> {
    // Your code here
    Ok(())
}
```

### Async/Await

All BLE operations are async:

```rust
adapter.start_scan().await?;
let devices = adapter.get_discovered_devices().await;
adapter.connect(&device_id).await?;
```

### Timeouts

Use `tokio::time::timeout` for operations that might hang:

```rust
let packet = timeout(Duration::from_secs(2), rx.recv())
    .await
    .expect("Timeout waiting for data");
```

## Additional Resources

- **[Architecture Documentation](../../docs/architecture.md)** - System design
- **[API Examples](../../docs/api-examples.md)** - More code patterns
- **[User Guide](../../docs/user-guide.md)** - End-user documentation
- **[Development Guide](../../docs/development.md)** - Contributing

## Need Help?

If you have questions or run into issues:

1. Check the inline documentation in the example code
2. Read the full API documentation: `cargo doc --no-deps --open`
3. Look at the integration tests in `tests/`
4. Open an issue on GitHub

---

Happy coding! These examples are designed to get you started quickly with Heart Beat. Feel free to modify and experiment with them.
