# Latency Measurement Design

## Overview

This document defines the comprehensive approach for measuring end-to-end latency in the Heart Beat application, from BLE heart rate notification receipt to Flutter UI update. The goal is to validate the P95 < 100ms requirement specified in product.md.

## Measurement Points

The heart rate data flows through the following pipeline stages:

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   BLE Event  │ -> │     Rust     │ -> │    Kalman    │ -> │     FRB      │ -> │   Flutter    │
│ (btleplug)   │    │  HR Parser   │    │    Filter    │    │  StreamSink  │    │     UI       │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
       T0                  T1                  T2                  T3                  T4
```

### Timestamp Capture Points

1. **T0: BLE Notification Received** (`rust/src/adapters/btleplug_adapter.rs:662`)
   - Location: `notification_stream.next().await` in `subscribe_hr()`
   - Captures: `std::time::Instant::now()` immediately upon notification
   - Clock: Monotonic (for accurate duration measurement)

2. **T1: HR Parsing Complete** (`rust/src/api.rs:667`)
   - Location: After `parse_heart_rate(&data)` success
   - Captures: Time after parsing BLE packet
   - Latency: T1 - T0 (parsing overhead)

3. **T2: Kalman Filtering Complete** (`rust/src/api.rs:672`)
   - Location: After `kalman_filter.filter_if_valid()` returns
   - Captures: Time after signal processing
   - Latency: T2 - T1 (filtering overhead)

4. **T3: Data Emitted to FRB** (`rust/src/api.rs:717`)
   - Location: After `emit_hr_data(filtered_data)` returns
   - Captures: Time after broadcast to FRB channels
   - Latency: T3 - T2 (emission overhead)

5. **T4: Flutter UI Receives Data** (`lib/src/screens/workout_screen.dart` or data layer)
   - Location: StreamBuilder/listener receives data
   - Captures: `DateTime.now()` when Flutter receives data
   - Latency: T4 - T0 (end-to-end latency)

## Instrumentation Strategy

### Rust-side Implementation

#### Data Structure Enhancement
Add `receive_instant` field to `HeartRateMeasurement` to capture T0:

```rust
// rust/src/domain/heart_rate.rs
pub struct HeartRateMeasurement {
    pub bpm: u16,
    pub rr_intervals: Vec<u16>,
    pub sensor_contact: bool,
    pub receive_instant: std::time::Instant,  // NEW: Monotonic timestamp
}
```

Propagate timestamp through `FilteredHeartRate`:

```rust
// rust/src/domain/heart_rate.rs
pub struct FilteredHeartRate {
    pub raw_bpm: u16,
    pub filtered_bpm: u16,
    pub rmssd: Option<f64>,
    pub filter_variance: Option<f64>,
    pub battery_level: Option<u8>,
    pub timestamp: u64,  // System time (existing)
    pub receive_instant_micros: u64,  // NEW: Monotonic time in microseconds since epoch
}
```

#### Timestamp Capture in BLE Adapter

```rust
// rust/src/adapters/btleplug_adapter.rs (line ~662)
while let Some(notification) = notification_stream.next().await {
    let receive_instant = std::time::Instant::now();  // T0: Capture immediately

    if notification.uuid != HR_MEASUREMENT_UUID {
        continue;
    }

    // Pass both data and timestamp through channel
    if tx.send((notification.value, receive_instant)).await.is_err() {
        tracing::debug!("HR notification receiver dropped");
        break;
    }
}
```

#### Processing Pipeline Instrumentation

```rust
// rust/src/api.rs (line ~664)
while let Some((data, receive_instant)) = hr_receiver.recv().await {
    let t0_micros = receive_instant.elapsed().as_micros() as u64;

    tracing::debug!("Received {} bytes of HR data at T0", data.len());

    match parse_heart_rate(&data) {
        Ok(measurement) => {
            let t1_micros = receive_instant.elapsed().as_micros() as u64;
            tracing::trace!("HR parsing latency: {}μs", t1_micros - t0_micros);

            // Kalman filtering
            let filtered_bpm_f64 = kalman_filter.filter_if_valid(measurement.bpm as f64);
            let filtered_bpm = filtered_bpm_f64.round() as u16;

            let t2_micros = receive_instant.elapsed().as_micros() as u64;
            tracing::trace!("Kalman filter latency: {}μs", t2_micros - t1_micros);

            // ... rest of processing ...

            let filtered_data = FilteredHeartRate {
                raw_bpm: measurement.bpm,
                filtered_bpm,
                rmssd,
                filter_variance: Some(filter_variance),
                battery_level: None,
                timestamp,
                receive_instant_micros: t0_micros,  // Pass T0 to Flutter
            };

            let receivers = emit_hr_data(filtered_data);
            let t3_micros = receive_instant.elapsed().as_micros() as u64;
            tracing::trace!("FRB emit latency: {}μs", t3_micros - t2_micros);
            tracing::debug!("Total Rust processing latency: {}μs", t3_micros);
        }
        Err(e) => {
            tracing::error!("Failed to parse HR data: {}", e);
        }
    }
}
```

### Flutter-side Implementation

#### Latency Calculation Service

Create `lib/src/services/latency_tracker.dart`:

```dart
class LatencyTracker {
  final List<int> _latencySamples = [];
  static const int maxSamples = 1000;  // Keep last 1000 samples
  static const Duration logInterval = Duration(seconds: 30);

  Timer? _logTimer;

  void start() {
    _logTimer = Timer.periodic(logInterval, (_) => _logPercentiles());
  }

  void recordLatency(int receiveInstantMicros) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final latencyMicros = now - receiveInstantMicros;

    _latencySamples.add(latencyMicros);

    // Keep only last maxSamples
    if (_latencySamples.length > maxSamples) {
      _latencySamples.removeAt(0);
    }
  }

  void _logPercentiles() {
    if (_latencySamples.isEmpty) return;

    final sorted = List<int>.from(_latencySamples)..sort();
    final p50 = _getPercentile(sorted, 0.50);
    final p95 = _getPercentile(sorted, 0.95);
    final p99 = _getPercentile(sorted, 0.99);
    final max = sorted.last;

    print('Latency Stats (n=${sorted.length}): '
          'P50=${p50}μs (${(p50/1000).toStringAsFixed(1)}ms), '
          'P95=${p95}μs (${(p95/1000).toStringAsFixed(1)}ms), '
          'P99=${p99}μs (${(p99/1000).toStringAsFixed(1)}ms), '
          'Max=${max}μs (${(max/1000).toStringAsFixed(1)}ms)');

    // Log warning if P95 exceeds target
    if (p95 > 100000) {  // 100ms in microseconds
      print('⚠️  WARNING: P95 latency exceeds 100ms target!');
    }
  }

  int _getPercentile(List<int> sorted, double percentile) {
    final index = (sorted.length * percentile).ceil() - 1;
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  Map<String, dynamic> getStats() {
    if (_latencySamples.isEmpty) {
      return {'count': 0};
    }

    final sorted = List<int>.from(_latencySamples)..sort();
    return {
      'count': sorted.length,
      'p50_micros': _getPercentile(sorted, 0.50),
      'p95_micros': _getPercentile(sorted, 0.95),
      'p99_micros': _getPercentile(sorted, 0.99),
      'max_micros': sorted.last,
      'min_micros': sorted.first,
    };
  }

  void stop() {
    _logTimer?.cancel();
  }
}
```

#### Integration in Workout Screen

```dart
// lib/src/screens/workout_screen.dart
class _WorkoutScreenState extends State<WorkoutScreen> {
  final LatencyTracker _latencyTracker = LatencyTracker();

  @override
  void initState() {
    super.initState();
    _latencyTracker.start();

    // Subscribe to HR stream
    api.createHrStream().listen((hrData) {
      _latencyTracker.recordLatency(hrData.receiveInstantMicros);
      setState(() {
        _currentHeartRate = hrData;
      });
    });
  }

  @override
  void dispose() {
    _latencyTracker.stop();
    super.dispose();
  }
}
```

## Measurement Precision

### Clock Selection
- **Rust**: `std::time::Instant` (monotonic, unaffected by system clock changes)
- **Flutter**: `DateTime.now().microsecondsSinceEpoch` (system clock)

### Cross-Runtime Considerations
- Cannot directly subtract `Instant` from `DateTime` (different clock bases)
- Solution: Convert `Instant` to elapsed microseconds at capture point, pass as u64
- Flutter calculates: `now() - receive_instant_micros` for end-to-end latency

### Overhead Minimization
- Timestamp capture is ~10ns (CPU TSC read)
- Negligible compared to target 100ms latency
- Trace-level logging disabled in release builds (zero-cost)

## Benchmark Suite Design

### Criterion Benchmarks (Rust)

Create `rust/benches/latency_bench.rs`:

```rust
use criterion::{black_box, criterion_group, criterion_main, Criterion};
use heart_beat::domain::heart_rate::parse_heart_rate;
use heart_beat::domain::filters::KalmanFilter;

fn bench_hr_parsing(c: &mut Criterion) {
    // Realistic HR packet with RR-intervals
    let data = &[0x16, 72, 0x34, 0x03, 0x3E, 0x03, 0x2F, 0x03];

    c.bench_function("parse_heart_rate", |b| {
        b.iter(|| {
            parse_heart_rate(black_box(data))
        });
    });
}

fn bench_kalman_filter(c: &mut Criterion) {
    let mut filter = KalmanFilter::default();

    c.bench_function("kalman_filter_update", |b| {
        b.iter(|| {
            filter.filter_if_valid(black_box(72.0))
        });
    });
}

criterion_group!(benches, bench_hr_parsing, bench_kalman_filter);
criterion_main!(benches);
```

### Baseline Targets
- HR Parsing: < 5μs (simple byte manipulation)
- Kalman Filter: < 10μs (matrix operations)
- Total Rust Processing: < 50μs (leaves 50ms for BLE/FRB/Flutter)

## CI Integration Strategy

### Benchmark Workflow
`.github/workflows/benchmark.yml`:
- Trigger: On PR and push to main
- Run `cargo bench` on consistent hardware (GitHub-hosted runner)
- Compare against baseline stored in repo (`target/criterion/baseline`)
- Fail CI if any benchmark regresses >10%
- Archive results as GitHub Actions artifacts

### Regression Detection
Use `criterion-compare-action` to automatically:
- Checkout baseline from main branch
- Run benchmarks on PR branch
- Generate comparison report
- Comment on PR with results

## Latency Budget Allocation

Target: P95 < 100ms end-to-end

| Component | Budget | Notes |
|-----------|--------|-------|
| BLE Stack | 30ms | BlueZ/btleplug notification delivery |
| Rust Processing | 1ms | Parse + Filter + Emit (measured via tracing) |
| FRB Crossing | 5ms | Rust -> Dart FFI boundary |
| Flutter Event Loop | 10ms | Tokio -> Flutter isolate |
| UI Rendering | 16ms | Widget build + paint (1 frame @ 60fps) |
| **Buffer** | 38ms | Safety margin for variance |
| **Total** | 100ms | P95 target |

## Production Monitoring

### Telemetry Collection
- Log P50/P95/P99 every 30 seconds to console
- Exportable latency statistics via API (for post-session analysis)
- Optional: Send to analytics service (future enhancement)

### Alerting
- UI warning if P95 exceeds 100ms during session
- Dev mode: Overlay showing real-time latency graph

## Testing & Validation

### Validation Protocol (Task 9)
1. Build instrumented release APK with latency logging enabled
2. Deploy to physical Android device (not emulator)
3. Connect to real Coospo HW9 BLE HR monitor
4. Perform 30+ minute workout session (walking/running)
5. Collect latency samples via `adb logcat`
6. Calculate P50/P95/P99 from collected data
7. Verify P95 < 100ms requirement met

### Data Collection Script
```bash
# Extract latency stats from logcat
adb logcat | grep "Latency Stats" > latency_log.txt

# Post-processing with Python/awk to compute percentiles
```

## References

- [product.md](../.spec-workflow/steering/product.md): P95 < 100ms requirement
- [tech.md](../.spec-workflow/steering/tech.md): Rust/Flutter architecture
- [rust/src/api.rs](../rust/src/api.rs): Current HR data pipeline
- [rust/src/adapters/btleplug_adapter.rs](../rust/src/adapters/btleplug_adapter.rs): BLE notification handler
