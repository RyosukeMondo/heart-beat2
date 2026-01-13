//! Integration tests for Kalman filter in the HR data pipeline.
//!
//! These tests verify that the Kalman filter correctly integrates with the
//! HR measurement pipeline, providing noise reduction while maintaining
//! responsiveness to real heart rate changes.

use heart_beat::adapters::mock_adapter::{MockAdapter, MockConfig};
use heart_beat::domain::heart_rate::parse_heart_rate;
use heart_beat::ports::BleAdapter;

/// Test that the Kalman filter smooths noisy HR data.
///
/// This test generates a sequence of HR measurements with realistic noise
/// and verifies that filtering reduces the variance while keeping the mean close to truth.
#[tokio::test]
async fn test_kalman_filter_smooths_noisy_data() {
    // Configure mock adapter to simulate noisy HR readings around 75 BPM
    let config = MockConfig {
        baseline_bpm: 75,
        noise_range: 3,         // ±3 BPM noise (typical for optical sensors)
        spike_probability: 0.0, // No spikes for this test
        ..Default::default()
    };

    let adapter = MockAdapter::with_config(config);

    // Discover devices and connect
    adapter.start_scan().await.unwrap();
    adapter.connect("mock-device-001").await.unwrap();
    let mut hr_stream = adapter.subscribe_hr().await.unwrap();

    // Collect raw measurements
    let mut raw_measurements = Vec::new();
    for _ in 0..20 {
        if let Some(data) = hr_stream.recv().await {
            let measurement = parse_heart_rate(&data).unwrap();
            raw_measurements.push(measurement.bpm as f64);
        }
    }

    // Calculate statistics on raw data
    let raw_mean: f64 = raw_measurements.iter().sum::<f64>() / raw_measurements.len() as f64;
    let raw_variance: f64 = raw_measurements
        .iter()
        .map(|x| (x - raw_mean).powi(2))
        .sum::<f64>()
        / raw_measurements.len() as f64;

    // Apply Kalman filter
    use heart_beat::domain::filters::KalmanFilter;
    let mut filter = KalmanFilter::default();
    let filtered_values: Vec<f64> = raw_measurements
        .iter()
        .map(|&x| filter.filter_if_valid(x))
        .collect();

    // Calculate statistics on filtered data (skip first 5 for warm-up)
    let filtered_mean: f64 =
        filtered_values[5..].iter().sum::<f64>() / (filtered_values.len() - 5) as f64;
    let filtered_variance: f64 = filtered_values[5..]
        .iter()
        .map(|x| (x - filtered_mean).powi(2))
        .sum::<f64>()
        / (filtered_values.len() - 5) as f64;

    // Assertions
    // 1. Filtered variance should be lower than raw variance (noise reduction)
    assert!(
        filtered_variance < raw_variance,
        "Filtered variance ({:.2}) should be lower than raw variance ({:.2})",
        filtered_variance,
        raw_variance
    );

    // 2. Filtered mean should be close to the true mean (75 BPM)
    assert!(
        (filtered_mean - 75.0).abs() < 2.0,
        "Filtered mean ({:.2}) should be within 2 BPM of true mean (75.0)",
        filtered_mean
    );

    // 3. Filtered values should still be physiologically plausible
    for value in &filtered_values {
        assert!(
            *value >= 30.0 && *value <= 220.0,
            "Filtered value {} should be in valid range [30, 220]",
            value
        );
    }

    adapter.disconnect().await.unwrap();
}

/// Test that the Kalman filter tracks step changes in heart rate.
///
/// This simulates a realistic scenario where HR increases during exercise onset.
#[tokio::test]
async fn test_kalman_filter_tracks_step_changes() {
    // Start at resting HR (70 BPM)
    let config_rest = MockConfig {
        baseline_bpm: 70,
        noise_range: 2,
        spike_probability: 0.0,
        ..Default::default()
    };

    let adapter = MockAdapter::with_config(config_rest);
    adapter.start_scan().await.unwrap();
    adapter.connect("mock-device-001").await.unwrap();
    let mut hr_stream = adapter.subscribe_hr().await.unwrap();

    // Initialize filter with resting HR
    use heart_beat::domain::filters::KalmanFilter;
    let mut filter = KalmanFilter::default();

    // Feed resting HR for 10 measurements (filter converges)
    for _ in 0..10 {
        if let Some(data) = hr_stream.recv().await {
            let measurement = parse_heart_rate(&data).unwrap();
            filter.filter_if_valid(measurement.bpm as f64);
        }
    }

    adapter.disconnect().await.unwrap();

    // Now simulate exercise (HR jumps to 140 BPM)
    let config_exercise = MockConfig {
        baseline_bpm: 140,
        noise_range: 3,
        spike_probability: 0.0,
        ..Default::default()
    };

    let adapter = MockAdapter::with_config(config_exercise);
    adapter.start_scan().await.unwrap();
    adapter.connect("mock-device-001").await.unwrap();
    let mut hr_stream = adapter.subscribe_hr().await.unwrap();

    // Track how the filter responds to the step change
    let mut filtered_values = Vec::new();
    for _ in 0..30 {
        if let Some(data) = hr_stream.recv().await {
            let measurement = parse_heart_rate(&data).unwrap();
            let filtered = filter.filter_if_valid(measurement.bpm as f64);
            filtered_values.push(filtered);
        }
    }

    // Assertions
    // 1. Filter should eventually track to the new level
    let final_value = filtered_values.last().unwrap();
    assert!(
        *final_value > 120.0,
        "Filter should track step change: final value {:.2} should exceed 120 BPM",
        final_value
    );

    // 2. Filter should show gradual transition (not instant jump)
    // First filtered value after step change should still be close to resting
    let first_after_jump = filtered_values.first().unwrap();
    assert!(
        *first_after_jump < 100.0,
        "Filter should transition gradually: first value {:.2} should be < 100 BPM",
        first_after_jump
    );

    // 3. Filter should approach new setpoint within 20 measurements
    let converged_value = filtered_values[20];
    assert!(
        (converged_value - 140.0).abs() < 10.0,
        "Filter should converge within 20 samples: value {:.2} should be within 10 BPM of 140",
        converged_value
    );

    adapter.disconnect().await.unwrap();
}

/// Test that the Kalman filter rejects invalid measurements.
///
/// This ensures sensor artifacts (impossible HR values) don't corrupt the filter state.
#[tokio::test]
async fn test_kalman_filter_rejects_invalid_measurements() {
    use heart_beat::domain::filters::KalmanFilter;
    let mut filter = KalmanFilter::default();

    // Establish baseline with valid measurements
    for _ in 0..10 {
        filter.update(75.0);
    }
    let baseline = filter.update(75.0);

    // Send invalid measurements (sensor artifacts)
    let invalid_measurements = vec![250.0, 20.0, 300.0, 5.0, 500.0];

    for invalid in invalid_measurements {
        let filtered = filter.filter_if_valid(invalid);
        // Filter should preserve state and not jump to invalid value
        assert!(
            (filtered - baseline).abs() < 1.0,
            "Filter should reject invalid value {}: filtered={:.2}, baseline={:.2}",
            invalid,
            filtered,
            baseline
        );
    }

    // Verify filter still works after rejecting invalid measurements
    let valid_after = filter.filter_if_valid(76.0);
    assert!(
        valid_after > 75.0 && valid_after < 77.0,
        "Filter should still respond to valid measurements after rejecting invalid ones: {:.2}",
        valid_after
    );
}

/// Test filter variance decreases as it converges.
///
/// This verifies that the confidence indicator behaves correctly.
#[tokio::test]
async fn test_kalman_filter_variance_convergence() {
    use heart_beat::domain::filters::KalmanFilter;
    let mut filter = KalmanFilter::default();

    // Initial variance should be high (filter not yet converged)
    let initial_variance = filter.variance();
    assert!(
        initial_variance > 1.0,
        "Initial variance should be high: {:.2}",
        initial_variance
    );

    // Feed consistent measurements
    for _ in 0..20 {
        filter.update(75.0);
    }

    // Variance should decrease significantly
    let converged_variance = filter.variance();
    assert!(
        converged_variance < initial_variance,
        "Variance should decrease after convergence: initial={:.2}, converged={:.2}",
        initial_variance,
        converged_variance
    );

    // Converged variance should indicate high confidence (< 1.0)
    assert!(
        converged_variance < 1.0,
        "Converged variance should indicate high confidence: {:.2}",
        converged_variance
    );
}

/// Test filter behavior across simulated reconnection.
///
/// This verifies that filter state is preserved when reconnection occurs
/// (though in current implementation, each connection creates a new filter).
#[tokio::test]
async fn test_kalman_filter_across_reconnection() {
    use heart_beat::domain::filters::KalmanFilter;

    // Simulate first connection session
    let mut filter = KalmanFilter::default();

    // Converge filter during first session
    for _ in 0..20 {
        filter.update(75.0);
    }
    let session1_variance = filter.variance();

    // In current implementation, reconnection creates a new filter
    // This test documents current behavior
    // TODO: If we want to preserve filter state across reconnections,
    // we'd need to store filter state globally and restore it

    // For now, verify that creating a new filter starts fresh
    let filter2 = KalmanFilter::default();
    let fresh_variance = filter2.variance();

    assert!(
        fresh_variance > session1_variance,
        "New filter should have higher variance than converged filter: \
         fresh={:.2}, converged={:.2}",
        fresh_variance,
        session1_variance
    );
}

/// Test filter latency stays under 100ms requirement.
///
/// This ensures the filter doesn't introduce significant latency.
#[tokio::test]
async fn test_kalman_filter_latency() {
    use heart_beat::domain::filters::KalmanFilter;
    use std::time::Instant;

    let mut filter = KalmanFilter::default();

    // Measure filter update latency over many iterations
    let iterations = 1000;
    let start = Instant::now();

    for i in 0..iterations {
        filter.filter_if_valid(75.0 + (i % 10) as f64);
    }

    let elapsed = start.elapsed();
    let avg_latency_us = elapsed.as_micros() / iterations;

    // Filter operation should be very fast (< 100 microseconds per update)
    assert!(
        avg_latency_us < 100,
        "Average filter latency ({} μs) should be under 100 μs",
        avg_latency_us
    );

    // Total latency for realistic measurement rate (1 Hz) should be negligible
    assert!(
        avg_latency_us < 1000,
        "Filter should not add noticeable latency at 1 Hz: {} μs",
        avg_latency_us
    );
}
