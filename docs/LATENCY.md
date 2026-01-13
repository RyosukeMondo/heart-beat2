# Latency Requirements and Budget

## Overview

Heart Beat is designed for real-time biofeedback during exercise, requiring minimal latency from heart rate sensor measurement to UI display. This document describes the latency requirements, budget allocation, measurement methodology, and debugging guidance.

## Latency Requirement

**P95 latency < 100ms** from BLE notification receipt to Flutter UI update.

This requirement ensures that users receive timely feedback when their heart rate deviates from the target training zone, enabling effective real-time guidance during workouts.

## Latency Budget

The end-to-end latency is allocated across the following components:

| Component | Budget | Notes |
|-----------|--------|-------|
| **BLE Stack** | 10-30ms | OS BLE stack + hardware latency (not directly controllable) |
| **Rust Processing** | 5-15ms | Parsing, Kalman filter, HRV calculation, state machine |
| **FRB Bridge** | 5-10ms | Rust → Dart FFI serialization and transfer |
| **Flutter UI** | 10-30ms | Widget rebuild, rendering, frame sync |
| **Total Target** | **30-85ms** | Well under 100ms P95 requirement with margin for variance |

### BLE Stack (10-30ms)

The BLE stack latency includes:
- BLE radio interrupt processing
- OS BLE stack event delivery
- btleplug library processing

This is largely outside our control but typically stable at 10-20ms on modern devices.

### Rust Processing (5-15ms)

The Rust core processing includes:
1. **HR Packet Parsing** (~1-5μs): Parse BLE Heart Rate Service packet
2. **Kalman Filtering** (~1-10μs): Single filter update operation
3. **HRV Calculation** (~5-50μs): RMSSD calculation when RR-intervals present
4. **State Machine** (~1-10μs): Transition processing and zone classification

**Critical Path Optimization:**
- Zero-copy parsing where possible
- Pre-allocated buffers to avoid heap allocation in hot path
- Kalman filter state maintained across updates (no cold start penalty)

See `rust/benches/latency_bench.rs` for detailed component benchmarks.

### FRB Bridge (5-10ms)

Flutter Rust Bridge (FRB v2) serialization overhead:
- Type conversion (Rust → Dart)
- StreamSink message passing
- Dart isolate scheduling

**Optimization:**
- Minimal data structure (FilteredHeartRate is 48 bytes)
- Direct StreamSink updates (no buffering)
- FRB v2 uses optimized code generation

### Flutter UI (10-30ms)

Flutter UI update latency includes:
- StreamBuilder notification
- Widget tree rebuild
- Layout and paint
- Frame buffer swap (vsync)

**Optimization:**
- Minimal widget rebuilds (StreamBuilder scoped to HR display)
- No expensive computations in build() methods
- Pre-computed layouts where possible

## Measurement Methodology

### Instrumentation Points

The system captures two high-precision timestamps:

1. **BLE Receive Timestamp** (`rust/src/adapters/btleplug_adapter.rs:665`):
   - Captured immediately when BLE notification arrives
   - Uses `std::time::Instant` (monotonic clock)
   - Logged at debug level for troubleshooting

2. **UI Receive Timestamp** (Flutter `workout_screen.dart`):
   - Captured when `FilteredHeartRate` arrives in UI
   - Uses `DateTime.now().microsecondsSinceEpoch`
   - Compared against `receive_timestamp_micros` from Rust

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Latency Measurement                      │
└─────────────────────────────────────────────────────────────┘

BLE Device                                              Flutter UI
    │                                                        │
    │ HR Notification                                        │
    ├────────> [t0] BLE Stack (10-30ms)                     │
    │                                                        │
    ├────────> [t1] btleplug_adapter.rs:665                 │
    │               Instant::now() captured                 │
    │                                                        │
    ├────────> [t2] Parse + Filter (5-15ms)                │
    │               rust/src/api.rs                          │
    │                                                        │
    ├────────> [t3] FRB Serialization (5-10ms)             │
    │                                                        │
    ├────────> [t4] Flutter StreamBuilder (10-30ms)        │
    │               DateTime.now() - t1 = end-to-end       │
    │                                                        │
    └────────> [UI Update]                                  │

Total Latency = t4 - t1 (measured)
BLE Stack Latency = t1 - t0 (not directly measurable)
```

### Accessing Latency Data

**Rust Side:**
```rust
// Timestamp captured immediately on BLE notification
let receive_timestamp = std::time::Instant::now();

// Propagated through HeartRateMeasurement
let measurement = HeartRateMeasurement {
    bpm,
    rr_intervals,
    sensor_contact,
    receive_timestamp: Some(receive_timestamp),
};

// Converted to Unix epoch microseconds for Flutter
let receive_timestamp_micros = Some(convert_instant_to_unix_micros(receive_timestamp));

// Exposed via FilteredHeartRate
FilteredHeartRate {
    raw_bpm,
    filtered_bpm,
    rmssd,
    receive_timestamp_micros,
    ..
}
```

**Flutter Side:**
```dart
// Calculate latency when data arrives
final uiReceiveTime = DateTime.now().microsecondsSinceEpoch;
final bleReceiveTime = filteredHeartRate.receiveTimestampMicros;

if (bleReceiveTime != null) {
  final latencyMicros = uiReceiveTime - bleReceiveTime;
  final latencyMs = latencyMicros / 1000.0;

  // Log for analysis
  debugPrint('End-to-end latency: ${latencyMs.toStringAsFixed(2)}ms');
}
```

### Calculating Percentiles

To validate the P95 < 100ms requirement:

1. **Collect Samples**: Capture latency for every HR update during a 30+ minute workout
2. **Store Measurements**: Append to a list/buffer in memory or log file
3. **Calculate P95**: Sort samples and select the 95th percentile value

```dart
// Example Flutter implementation
List<double> latencySamples = [];

void onHeartRateUpdate(FilteredHeartRate hr) {
  final uiTime = DateTime.now().microsecondsSinceEpoch;
  final bleTime = hr.receiveTimestampMicros;

  if (bleTime != null) {
    final latencyMs = (uiTime - bleTime) / 1000.0;
    latencySamples.add(latencyMs);
  }
}

// Calculate statistics after workout
double calculateP95() {
  latencySamples.sort();
  final index = (latencySamples.length * 0.95).floor();
  return latencySamples[index];
}
```

## Benchmarking

### Rust Component Benchmarks

Run the criterion benchmark suite to measure Rust processing latency:

```bash
cd rust
cargo bench
```

**Key Benchmarks:**
- `parse_heart_rate_simple`: Minimal packet parsing (~1-5μs)
- `parse_heart_rate_with_rr`: Parsing with RR-intervals (~5-10μs)
- `kalman_filter_update`: Single filter update (~1-5μs)
- `calculate_rmssd_short`: HRV calculation, 5 intervals (~5-20μs)
- `full_pipeline`: Complete processing path (~10-50μs)

Results are stored in `target/criterion/` and include:
- Mean, median, and standard deviation
- Comparison against previous baseline
- Statistical outlier analysis

### CI Regression Detection

GitHub Actions workflow `.github/workflows/benchmark.yml` runs on:
- Pull requests (compare against main branch baseline)
- Main branch commits (update baseline)

**Regression Threshold:** 10% increase in P95 latency fails CI

### End-to-End Measurement

To measure real-world latency on device:

1. **Build Instrumented Version**:
   ```bash
   ./scripts/dev-linux.sh debug  # Linux desktop
   # OR
   ./scripts/adb-install.sh      # Android device
   ```

2. **Enable Debug Logging**:
   ```bash
   # Rust logging
   export RUST_LOG=heart_beat=debug

   # Android logging
   ./scripts/adb-logs.sh
   ```

3. **Run Workout Session**:
   - Connect to Coospo HW9
   - Start a training session
   - Exercise for 30+ minutes to collect sufficient samples
   - Latency logged at info level: "End-to-end latency: X.XXms"

4. **Analyze Results**:
   ```bash
   # Extract latency samples from logs
   grep "End-to-end latency" logs.txt | \
     awk '{print $4}' | \
     sort -n > latency_samples.txt

   # Calculate P95 (95th percentile)
   python3 -c "
   import sys
   samples = sorted([float(x.strip('ms')) for x in open('latency_samples.txt')])
   p50 = samples[int(len(samples) * 0.50)]
   p95 = samples[int(len(samples) * 0.95)]
   p99 = samples[int(len(samples) * 0.99)]
   print(f'P50: {p50:.2f}ms, P95: {p95:.2f}ms, P99: {p99:.2f}ms')
   "
   ```

## Debugging High Latency

If P95 latency exceeds 100ms, follow this diagnostic process:

### 1. Identify the Bottleneck

Enable detailed tracing:

```bash
# Rust detailed tracing
RUST_LOG=heart_beat::ble=trace,heart_beat::domain=trace cargo run --bin cli

# Android detailed logging
./scripts/adb-logs.sh
```

Look for:
- Long gaps between log entries (indicates where delay occurs)
- GC pauses in Flutter (check Observatory/DevTools)
- BLE disconnection/reconnection events

### 2. Check Rust Processing Time

The Rust processing component should be consistently < 1ms. If higher:

**Run benchmarks:**
```bash
cd rust
cargo bench
```

**Profile with flamegraph:**
```bash
cargo install flamegraph
cargo flamegraph --bench latency_bench
```

**Common issues:**
- Heap allocation in hot path → Use pre-allocated buffers
- Expensive HRV calculation → Limit RR-interval window size
- State machine complexity → Simplify transition logic

### 3. Check FRB Bridge Performance

If the Rust → Flutter transfer is slow:

**Verify data structure size:**
```rust
println!("FilteredHeartRate size: {}", std::mem::size_of::<FilteredHeartRate>());
```

Should be ≤ 64 bytes. If larger:
- Remove unnecessary fields
- Use compact data types (u8/u16 instead of u32/u64)
- Consider splitting into separate streams

### 4. Check Flutter UI Performance

Use Flutter DevTools to profile UI performance:

1. **Open DevTools**:
   ```bash
   flutter pub global activate devtools
   flutter pub global run devtools
   ```

2. **Check frame rendering**:
   - Target: 60 FPS (16.67ms per frame)
   - If frames drop below 60 FPS, UI rebuild is too expensive

3. **Profile rebuild tree**:
   - Ensure StreamBuilder is scoped to minimal widget subtree
   - Avoid expensive operations in build() methods
   - Use `const` constructors where possible

**Common issues:**
- Full-screen rebuild on every HR update
- Synchronous I/O in UI thread
- Unoptimized layout calculations

### 5. Check BLE Stack Health

BLE stack latency is typically stable, but can degrade if:

**Connection issues:**
```bash
# Android BLE logs
adb logcat | grep -i "bluetooth\|gatt"
```

Look for:
- Connection interval changes (should be stable at 1s for HW9)
- MTU negotiation failures
- Signal strength issues (RSSI too low)

**Fix:**
- Reduce distance to sensor
- Ensure phone BLE antenna not blocked
- Check for BLE interference from other devices

### 6. System-Level Issues

If latency is inconsistent or spiky:

**Android battery optimization:**
- Ensure app is excluded from battery optimization
- Use Foreground Service to prevent process killing

**CPU throttling:**
- Check device thermal state
- Ensure sufficient CPU governor settings

**Background processes:**
- Close unnecessary apps
- Disable background sync during workouts

## Production Monitoring

### Recommended Logging Strategy

**During Development:**
- Log every HR update latency at debug level
- Capture detailed tracing for component-level timing

**In Production:**
- Log P50/P95/P99 latency every 60 seconds at info level
- Alert if P95 exceeds 100ms for more than 5 minutes
- Capture outliers (> 200ms) with full trace context

### Example Production Logging

```dart
class LatencyMonitor {
  final List<double> _window = [];
  static const _windowSize = 100;  // ~100 seconds of data at 1 Hz
  static const _reportInterval = Duration(seconds: 60);

  Timer? _reportTimer;

  void start() {
    _reportTimer = Timer.periodic(_reportInterval, (_) => _report());
  }

  void recordLatency(double latencyMs) {
    _window.add(latencyMs);
    if (_window.length > _windowSize) {
      _window.removeAt(0);
    }

    // Alert on extreme outlier
    if (latencyMs > 200.0) {
      _logger.warning('High latency detected: ${latencyMs.toStringAsFixed(2)}ms');
    }
  }

  void _report() {
    if (_window.isEmpty) return;

    final sorted = List<double>.from(_window)..sort();
    final p50 = sorted[(sorted.length * 0.50).floor()];
    final p95 = sorted[(sorted.length * 0.95).floor()];
    final p99 = sorted[(sorted.length * 0.99).floor()];

    _logger.info('Latency stats: P50=${p50.toStringAsFixed(1)}ms, '
                 'P95=${p95.toStringAsFixed(1)}ms, '
                 'P99=${p99.toStringAsFixed(1)}ms');

    // Alert if P95 exceeds requirement
    if (p95 > 100.0) {
      _logger.warning('P95 latency exceeds requirement: ${p95.toStringAsFixed(1)}ms');
    }
  }

  void stop() {
    _reportTimer?.cancel();
    _reportTimer = null;
  }
}
```

## References

- [Product Requirements](../.spec-workflow/steering/product.md): P95 < 100ms requirement
- [Technical Stack](../.spec-workflow/steering/tech.md): Architecture and latency constraints
- [Benchmark Suite](../rust/benches/latency_bench.rs): Rust component benchmarks
- [CI Workflow](../.github/workflows/benchmark.yml): Automated regression detection
- [BLE Adapter](../rust/src/adapters/btleplug_adapter.rs#L665): BLE timestamp capture
- [API Layer](../rust/src/api.rs): Rust → Flutter data flow
- [FilteredHeartRate](../rust/src/domain/heart_rate.rs#L116): Data structure with timestamp

## Changelog

- 2026-01-13: Initial documentation with latency budget and measurement methodology
