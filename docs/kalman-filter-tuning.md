# Kalman Filter Parameter Tuning for Coospo HW9

## Overview

The Kalman filter implementation uses default parameters optimized for the Coospo HW9 optical heart rate sensor. This document explains the rationale behind the chosen parameters and provides guidance for tuning if needed.

## Default Parameters

```rust
KalmanFilter::default()
// Equivalent to:
KalmanFilter::new(
    process_noise: 0.1,
    measurement_noise: 2.0
)
```

## Parameter Rationale

### Process Noise (0.1)

**Definition**: Expected variance in heart rate changes between measurements.

**Rationale for 0.1**:
- Heart rate changes gradually under normal conditions
- At 1 Hz sampling rate, HR typically doesn't jump more than 1-2 BPM between samples
- During steady-state (resting or constant exercise intensity), HR is very stable
- Value of 0.1 assumes HR changes are small and gradual

**Effect on filtering**:
- Lower values → Filter trusts model more, responds slower to changes
- Higher values → Filter assumes more HR variation, responds faster but less smoothing

### Measurement Noise (2.0)

**Definition**: Expected sensor noise variance in BPM².

**Rationale for 2.0**:
- Coospo HW9 uses optical (PPG) technology
- Optical sensors typically have ±2 BPM accuracy according to manufacturer specs
- Real-world testing confirms noise is in the 1-3 BPM range during stable conditions
- Variance of 2.0 BPM² corresponds to ~1.4 BPM standard deviation

**Effect on filtering**:
- Lower values → Filter trusts measurements more, less smoothing
- Higher values → Filter assumes noisier sensor, more aggressive smoothing

## Target Performance Metrics

Based on product requirements (product.md):

- **Accuracy**: ±5 BPM vs reference (chest strap HR monitor)
- **Latency**: Sub-100ms processing time
- **Responsiveness**: Track HR changes during exercise transitions

## Validation Results

### Noise Reduction
Integration tests confirm the default parameters achieve:
- Filtered variance < raw variance (noise reduction verified)
- Mean error < 2 BPM from true value
- All filtered values within physiological range (30-220 BPM)

### Step Response
Tests verify filter tracks HR changes appropriately:
- Gradual transition (not instant jump)
- Convergence within 20 samples (~20 seconds at 1 Hz)
- Final error < 10 BPM after step change of 70 BPM

### Latency
Measured filter performance:
- Average update latency: < 10 μs
- Well under 100ms requirement
- Negligible impact on overall system latency

## Tuning Guidelines

### When to Adjust Parameters

**Increase process_noise (e.g., 0.5-1.0) if**:
- Filter is too slow to track exercise intensity changes
- HR transitions appear "sluggish" or delayed
- Users report lag during interval training

**Decrease process_noise (e.g., 0.01-0.05) if**:
- Filter shows too much variance during steady-state
- Noise reduction is insufficient
- Values fluctuate excessively during resting

**Increase measurement_noise (e.g., 3.0-5.0) if**:
- Raw sensor data is noisier than expected
- Filter doesn't smooth enough
- Different sensor with lower accuracy

**Decrease measurement_noise (e.g., 1.0-1.5) if**:
- Filter is over-smoothing valid HR changes
- Using higher-quality sensor with better accuracy
- Need more responsiveness to real changes

### Tuning Procedure

1. **Collect reference data**:
   - Simultaneous recording with chest strap HR monitor
   - Various conditions: resting, steady exercise, transitions
   - At least 10 minutes per condition

2. **Analyze raw sensor characteristics**:
   - Calculate standard deviation during steady-state
   - Measure typical rate of change during transitions
   - Identify any systematic artifacts or spikes

3. **Adjust parameters incrementally**:
   - Change one parameter at a time
   - Test changes by 50-100% (e.g., 0.1 → 0.15 or 0.05)
   - Re-run integration tests after each change

4. **Validate against requirements**:
   - Accuracy: Mean absolute error < 5 BPM
   - Responsiveness: Convergence time < 30 seconds
   - Stability: Variance reduction ≥ 30%

## Implementation Notes

### Filter Initialization

```rust
// In rust/src/api.rs:621
let mut kalman_filter = KalmanFilter::default();
```

Filter is created once per connection session and maintains state across measurements.

### Warm-up Period

The first 5-10 measurements show higher variance as the filter converges. This is normal behavior:
- Initial covariance: 10.0 BPM²
- Converged covariance: <1.0 BPM² (after ~10-20 samples)

UI can use the `filter_variance` field to detect and indicate warm-up period.

### Sensor-Specific Tuning

For different sensors, use `KalmanFilter::new()` with custom parameters:

```rust
// Example for higher-noise sensor
let mut filter = KalmanFilter::new(
    0.2,  // Slightly higher process noise for faster tracking
    4.0   // Higher measurement noise for noisier sensor
);
```

## Testing

Run integration tests to validate parameter changes:

```bash
cargo test --test kalman_integration
```

Expected results:
- All 6 tests should pass
- `test_kalman_filter_smooths_noisy_data`: Confirms noise reduction
- `test_kalman_filter_tracks_step_changes`: Validates responsiveness
- `test_kalman_filter_variance_convergence`: Checks convergence behavior

## References

- Kalman filter implementation: `rust/src/domain/filters.rs`
- Integration tests: `rust/tests/kalman_integration.rs`
- Product requirements: `.spec-workflow/specs/kalman-filter-integration/`
- HR pipeline integration: `rust/src/api.rs:617-680`

## Future Considerations

- **Adaptive filtering**: Adjust parameters based on detected activity level
- **Multi-sensor fusion**: Combine optical + accelerometer for better accuracy
- **Per-user calibration**: Learn optimal parameters for individual users
- **Different sensor support**: Parameter profiles for various HR monitor brands
