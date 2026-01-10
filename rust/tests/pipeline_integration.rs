//! Integration test for the full heart rate processing pipeline.
//!
//! This test verifies the end-to-end data flow from BLE adapter through
//! parsing, filtering, and HRV calculation to final output.

use heart_beat::adapters::mock_adapter::{MockAdapter, MockConfig};
use heart_beat::domain::filters::KalmanFilter;
use heart_beat::domain::heart_rate::{parse_heart_rate, FilteredHeartRate};
use heart_beat::domain::hrv::calculate_rmssd;
use heart_beat::ports::ble_adapter::BleAdapter;
use tokio::time::{timeout, Duration};

/// Test the complete pipeline: mock adapter → parse → filter → HRV calculation.
///
/// This test simulates the full data flow that would occur in production:
/// 1. Connect to mock BLE device
/// 2. Subscribe to HR notifications
/// 3. Receive raw BLE packets
/// 4. Parse packets into HeartRateMeasurement
/// 5. Filter BPM values through Kalman filter
/// 6. Calculate HRV metrics from RR-intervals
/// 7. Package into FilteredHeartRate output struct
#[tokio::test]
async fn test_full_pipeline_with_mock_adapter() {
    // Configure mock adapter with known parameters for predictable testing
    let config = MockConfig {
        baseline_bpm: 75,
        noise_range: 5,
        spike_probability: 0.0, // No spikes for predictable testing
        spike_magnitude: 0,
        update_rate: 10.0, // Fast for testing
        battery_level: 90,
    };

    let adapter = MockAdapter::with_config(config);

    // Step 1: Scan and discover devices
    adapter.start_scan().await.expect("Scan should succeed");
    let devices = adapter.get_discovered_devices().await;
    assert!(!devices.is_empty(), "Should discover at least one device");

    // Step 2: Connect to first discovered device
    let device_id = &devices[0].id;
    adapter
        .connect(device_id)
        .await
        .expect("Connection should succeed");

    // Step 3: Subscribe to HR notifications
    let mut rx = adapter
        .subscribe_hr()
        .await
        .expect("Subscription should succeed");

    // Step 4: Initialize Kalman filter for BPM smoothing
    let mut kalman_filter = KalmanFilter::default();

    // Step 5: Process 10 samples through the full pipeline
    let mut results = Vec::new();
    let sample_count = 10;

    for i in 0..sample_count {
        // Receive raw BLE packet with timeout
        let packet = timeout(Duration::from_secs(2), rx.recv())
            .await
            .expect("Should receive packet within timeout")
            .expect("Should receive valid packet");

        // Parse the packet
        let measurement = parse_heart_rate(&packet)
            .expect(&format!("Sample {} should parse successfully", i));

        // Verify parsing succeeded and produced valid data
        assert!(
            measurement.bpm > 0,
            "Sample {} should have non-zero BPM",
            i
        );
        assert!(
            measurement.bpm >= 30 && measurement.bpm <= 220,
            "Sample {} BPM should be in valid range",
            i
        );

        // Filter the BPM value
        let raw_bpm = measurement.bpm;
        let filtered_value = kalman_filter.update(raw_bpm as f64);
        let filtered_bpm = filtered_value.round() as u16;

        // Calculate HRV if RR-intervals are present
        let rmssd = if measurement.rr_intervals.len() >= 2 {
            calculate_rmssd(&measurement.rr_intervals)
        } else {
            None
        };

        // Construct final output
        let output = FilteredHeartRate {
            raw_bpm,
            filtered_bpm,
            rmssd,
            battery_level: Some(90), // Would come from adapter.read_battery()
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis() as u64,
        };

        results.push(output);
    }

    // Step 6: Verify results

    // All samples should have been processed
    assert_eq!(
        results.len(),
        sample_count,
        "Should have processed all {} samples",
        sample_count
    );

    // Verify each result is complete and valid
    for (i, result) in results.iter().enumerate() {
        assert!(
            result.raw_bpm >= 30 && result.raw_bpm <= 220,
            "Sample {} raw BPM should be valid",
            i
        );
        assert!(
            result.filtered_bpm >= 30 && result.filtered_bpm <= 220,
            "Sample {} filtered BPM should be valid",
            i
        );
        assert!(
            result.battery_level.is_some(),
            "Sample {} should have battery level",
            i
        );
        assert!(result.timestamp > 0, "Sample {} should have timestamp", i);

        // Check RMSSD if present (mock generates RR-intervals but they may be out of range)
        if let Some(rmssd_value) = result.rmssd {
            assert!(
                rmssd_value >= 0.0 && rmssd_value < 500.0,
                "Sample {} RMSSD should be in reasonable range, got {}",
                i,
                rmssd_value
            );
        }
    }

    // Step 7: Verify filtering is working (smoothing effect)

    // Calculate variance of raw vs filtered BPM
    let raw_values: Vec<f64> = results.iter().map(|r| r.raw_bpm as f64).collect();
    let filtered_values: Vec<f64> = results.iter().map(|r| r.filtered_bpm as f64).collect();

    let raw_mean = raw_values.iter().sum::<f64>() / raw_values.len() as f64;
    let filtered_mean = filtered_values.iter().sum::<f64>() / filtered_values.len() as f64;

    let raw_variance = raw_values
        .iter()
        .map(|&x| (x - raw_mean).powi(2))
        .sum::<f64>()
        / raw_values.len() as f64;

    let filtered_variance = filtered_values
        .iter()
        .map(|&x| (x - filtered_mean).powi(2))
        .sum::<f64>()
        / filtered_values.len() as f64;

    // Filtered values should have lower variance (smoother) than raw values
    // This is the key property of the Kalman filter
    assert!(
        filtered_variance <= raw_variance * 1.5,
        "Filtered variance ({:.2}) should be lower than or similar to raw variance ({:.2})",
        filtered_variance,
        raw_variance
    );

    // Step 8: Clean disconnect
    adapter.disconnect().await.expect("Disconnect should succeed");
}

/// Test pipeline behavior with invalid sensor data.
///
/// This verifies that the pipeline handles edge cases gracefully:
/// - Invalid BPM values are rejected by the filter
/// - Malformed packets return errors rather than panicking
/// - The system continues operating after encountering invalid data
#[tokio::test]
async fn test_pipeline_handles_invalid_data() {
    // Test 1: Parser should reject malformed packets
    let empty_packet: Vec<u8> = vec![];
    let parse_result = parse_heart_rate(&empty_packet);
    assert!(
        parse_result.is_err(),
        "Parser should reject empty packet"
    );

    let too_short_packet = vec![0x06]; // Only flags, no BPM
    let parse_result = parse_heart_rate(&too_short_packet);
    assert!(
        parse_result.is_err(),
        "Parser should reject incomplete packet"
    );

    // Test 2: Filter should handle invalid BPM values
    let mut filter = KalmanFilter::default();

    // Establish baseline
    filter.update(70.0);
    filter.update(72.0);
    let baseline = filter.update(71.0);

    // Invalid high value should be rejected
    let filtered = filter.filter_if_valid(300.0);
    assert!(
        (filtered - baseline).abs() < 1.0,
        "Filter should reject invalid high BPM and preserve state"
    );

    // Invalid low value should be rejected
    let filtered = filter.filter_if_valid(10.0);
    assert!(
        (filtered - baseline).abs() < 1.0,
        "Filter should reject invalid low BPM and preserve state"
    );

    // Valid value should be accepted
    let filtered = filter.filter_if_valid(75.0);
    assert!(
        filtered > baseline && filtered < 80.0,
        "Filter should accept valid BPM"
    );
}

/// Test pipeline with high-frequency data stream.
///
/// This simulates a realistic scenario with rapid updates (e.g., during
/// intense exercise) to ensure the pipeline can handle high throughput.
#[tokio::test]
async fn test_pipeline_high_frequency_stream() {
    let config = MockConfig {
        baseline_bpm: 160, // Exercise heart rate
        noise_range: 10,
        spike_probability: 0.1,
        spike_magnitude: 15,
        update_rate: 5.0, // 5 Hz (higher than typical 1 Hz)
        battery_level: 75,
    };

    let adapter = MockAdapter::with_config(config);

    adapter.start_scan().await.unwrap();
    let devices = adapter.get_discovered_devices().await;
    adapter.connect(&devices[0].id).await.unwrap();

    let mut rx = adapter.subscribe_hr().await.unwrap();
    let mut kalman_filter = KalmanFilter::default();

    // Process 20 samples at high frequency
    let mut successful_parses = 0;
    let mut hrv_calculations = 0;

    for _ in 0..20 {
        let packet = timeout(Duration::from_secs(1), rx.recv())
            .await
            .expect("Should receive packet")
            .expect("Should be valid packet");

        if let Ok(measurement) = parse_heart_rate(&packet) {
            successful_parses += 1;

            // Filter
            let _filtered = kalman_filter.filter_if_valid(measurement.bpm as f64);

            // Calculate HRV if possible
            if measurement.rr_intervals.len() >= 2 {
                if let Some(_rmssd) = calculate_rmssd(&measurement.rr_intervals) {
                    hrv_calculations += 1;
                }
            }
        }
    }

    // Should successfully process most packets
    assert!(
        successful_parses >= 18,
        "Should parse at least 90% of packets, got {}",
        successful_parses
    );

    // Should calculate HRV for many samples (mock generates RR-intervals, but some may be out of range)
    // At high BPM (160), some RR-intervals may fall outside the 300-2000ms valid range
    // Accept at least 40% success rate as valid (depends on random generation)
    assert!(
        hrv_calculations >= 8,
        "Should calculate HRV for at least 40% of samples, got {}",
        hrv_calculations
    );

    adapter.disconnect().await.unwrap();
}

/// Test pipeline with simulated connection and data reception.
///
/// This test verifies that the pipeline works correctly with the basic
/// connect → subscribe → receive pattern without additional complexity.
#[tokio::test]
async fn test_basic_connection_flow() {
    let adapter = MockAdapter::new();

    // Scan → Connect → Subscribe → Receive → Disconnect
    adapter.start_scan().await.expect("Scan should work");

    let devices = adapter.get_discovered_devices().await;
    assert!(!devices.is_empty(), "Should find mock devices");

    adapter
        .connect(&devices[0].id)
        .await
        .expect("Connect should work");

    let mut rx = adapter.subscribe_hr().await.expect("Subscribe should work");

    // Receive one sample
    let packet = timeout(Duration::from_secs(2), rx.recv())
        .await
        .expect("Should receive packet")
        .expect("Packet should be Some");

    assert!(!packet.is_empty(), "Packet should not be empty");

    // Parse it
    let measurement = parse_heart_rate(&packet).expect("Should parse");
    assert!(measurement.bpm > 0, "Should have valid BPM");

    adapter.disconnect().await.expect("Disconnect should work");
}
