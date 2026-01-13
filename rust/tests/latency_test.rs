//! Latency acceptance test for the full heart rate processing pipeline.
//!
//! This test validates that the end-to-end latency from BLE packet arrival
//! to FilteredHeartRate emission meets the hard requirement of <100ms P95 latency.

use heart_beat::adapters::mock_adapter::{MockAdapter, MockConfig};
use heart_beat::domain::filters::KalmanFilter;
use heart_beat::domain::heart_rate::{parse_heart_rate, FilteredHeartRate};
use heart_beat::domain::hrv::calculate_rmssd;
use heart_beat::ports::ble_adapter::BleAdapter;
use tokio::time::{timeout, Duration, Instant};

/// Test that the full pipeline meets the <100ms P95 latency requirement.
///
/// This test runs 1000 iterations of the complete pipeline and measures the
/// end-to-end latency from BLE packet arrival to FilteredHeartRate construction.
/// The test asserts that the 95th percentile (P95) latency is less than 100ms.
///
/// Pipeline stages measured:
/// 1. BLE packet reception
/// 2. Heart rate parsing
/// 3. Kalman filtering
/// 4. HRV calculation (if RR-intervals present)
/// 5. FilteredHeartRate construction
#[tokio::test]
async fn test_p95_latency_under_100ms() {
    // Configure mock adapter for realistic testing
    let config = MockConfig {
        baseline_bpm: 75,
        noise_range: 5,
        spike_probability: 0.05,
        spike_magnitude: 10,
        update_rate: 10.0, // Fast updates to collect 1000 samples quickly
        battery_level: 90,
    };

    let adapter = MockAdapter::with_config(config);

    // Setup: Connect and subscribe
    adapter.start_scan().await.expect("Scan should succeed");
    let devices = adapter.get_discovered_devices().await;
    assert!(!devices.is_empty(), "Should discover at least one device");

    let device_id = &devices[0].id;
    adapter
        .connect(device_id)
        .await
        .expect("Connection should succeed");

    let mut rx = adapter
        .subscribe_hr()
        .await
        .expect("Subscription should succeed");

    let mut kalman_filter = KalmanFilter::default();

    // Collect latency measurements for 1000 samples
    let mut latencies_us: Vec<u128> = Vec::with_capacity(1000);
    let sample_count = 1000;

    for i in 0..sample_count {
        // Receive BLE packet (this includes network/BLE delay, not measured)
        let packet = timeout(Duration::from_secs(2), rx.recv())
            .await
            .unwrap_or_else(|_| panic!("Should receive packet {} within timeout", i))
            .unwrap_or_else(|| panic!("Packet {} should be Some", i));

        // Start timing AFTER packet arrival - measure processing only
        let start = Instant::now();

        // Parse the packet
        let measurement = parse_heart_rate(&packet)
            .unwrap_or_else(|_| panic!("Packet {} should parse successfully", i));

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
        let _output = FilteredHeartRate {
            raw_bpm,
            filtered_bpm,
            rmssd,
            filter_variance: None,
            battery_level: Some(90),
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis() as u64,
            receive_timestamp_micros: None,
        };

        // End timing - full pipeline complete
        let elapsed = start.elapsed();
        latencies_us.push(elapsed.as_micros());
    }

    // Clean disconnect
    adapter
        .disconnect()
        .await
        .expect("Disconnect should succeed");

    // Calculate percentiles
    latencies_us.sort_unstable();

    let p50_index = (sample_count as f64 * 0.50) as usize;
    let p95_index = (sample_count as f64 * 0.95) as usize;
    let p99_index = (sample_count as f64 * 0.99) as usize;

    let p50_us = latencies_us[p50_index];
    let p95_us = latencies_us[p95_index];
    let p99_us = latencies_us[p99_index];

    let p50_ms = p50_us as f64 / 1000.0;
    let p95_ms = p95_us as f64 / 1000.0;
    let p99_ms = p99_us as f64 / 1000.0;

    // Print latency statistics for visibility
    println!("\n=== Pipeline Latency Statistics ===");
    println!("Samples: {}", sample_count);
    println!("P50: {:.2}ms ({} µs)", p50_ms, p50_us);
    println!("P95: {:.2}ms ({} µs)", p95_ms, p95_us);
    println!("P99: {:.2}ms ({} µs)", p99_ms, p99_us);
    println!("===================================\n");

    // HARD REQUIREMENT: P95 latency must be < 100ms
    assert!(
        p95_ms < 100.0,
        "P95 latency ({:.2}ms) exceeds 100ms requirement",
        p95_ms
    );

    // Additional sanity checks
    assert!(
        p50_ms < 100.0,
        "P50 latency ({:.2}ms) should be well under 100ms",
        p50_ms
    );

    // P99 should also be reasonable (allow some overhead for CI)
    assert!(
        p99_ms < 200.0,
        "P99 latency ({:.2}ms) is unreasonably high",
        p99_ms
    );
}

/// Test that the pipeline maintains low latency under stress conditions.
///
/// This test validates latency with higher update rate and more variability
/// to ensure the system performs well even under challenging conditions.
#[tokio::test]
async fn test_latency_under_stress() {
    // Configure for higher stress: faster updates, more noise
    let config = MockConfig {
        baseline_bpm: 150, // Exercise heart rate
        noise_range: 15,
        spike_probability: 0.2, // More spikes
        spike_magnitude: 25,
        update_rate: 20.0, // Very fast updates (20 Hz)
        battery_level: 75,
    };

    let adapter = MockAdapter::with_config(config);

    adapter.start_scan().await.unwrap();
    let devices = adapter.get_discovered_devices().await;
    adapter.connect(&devices[0].id).await.unwrap();

    let mut rx = adapter.subscribe_hr().await.unwrap();
    let mut kalman_filter = KalmanFilter::default();

    // Collect 200 samples under stress
    let mut latencies_us: Vec<u128> = Vec::with_capacity(200);

    for _ in 0..200 {
        // Receive packet
        let packet = timeout(Duration::from_secs(1), rx.recv())
            .await
            .expect("Should receive packet")
            .expect("Packet should be Some");

        // Start timing AFTER packet arrival
        let start = Instant::now();

        let measurement = parse_heart_rate(&packet).unwrap();
        let raw_bpm = measurement.bpm;
        let filtered_value = kalman_filter.update(raw_bpm as f64);
        let filtered_bpm = filtered_value.round() as u16;

        let rmssd = if measurement.rr_intervals.len() >= 2 {
            calculate_rmssd(&measurement.rr_intervals)
        } else {
            None
        };

        let _output = FilteredHeartRate {
            raw_bpm,
            filtered_bpm,
            rmssd,
            filter_variance: None,
            battery_level: Some(75),
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis() as u64,
            receive_timestamp_micros: None,
        };

        let elapsed = start.elapsed();
        latencies_us.push(elapsed.as_micros());
    }

    adapter.disconnect().await.unwrap();

    // Calculate P95
    latencies_us.sort_unstable();
    let p95_index = (200.0 * 0.95) as usize;
    let p95_us = latencies_us[p95_index];
    let p95_ms = p95_us as f64 / 1000.0;

    println!("\n=== Stress Test Latency ===");
    println!("P95: {:.2}ms ({} µs)", p95_ms, p95_us);
    println!("===========================\n");

    // Under stress, still must meet the requirement
    assert!(
        p95_ms < 100.0,
        "P95 latency under stress ({:.2}ms) exceeds 100ms requirement",
        p95_ms
    );
}

/// Test that individual pipeline stages are fast.
///
/// This test measures the latency of individual components to identify
/// any bottlenecks in the pipeline.
#[test]
fn test_individual_stage_latency() {
    // Stage 1: Parsing
    let packet = vec![0x16, 75, 0x34, 0x03, 0x3E, 0x03, 0x2F, 0x03];
    let mut parse_latencies: Vec<u128> = Vec::new();

    for _ in 0..1000 {
        let start = Instant::now();
        let _measurement = parse_heart_rate(&packet).unwrap();
        parse_latencies.push(start.elapsed().as_micros());
    }

    parse_latencies.sort_unstable();
    let parse_p95 = parse_latencies[(1000.0 * 0.95) as usize] as f64 / 1000.0;

    println!("\n=== Individual Stage Latency ===");
    println!("Parse P95: {:.2}ms", parse_p95);

    // Stage 2: Kalman filtering
    let mut filter = KalmanFilter::default();
    let mut filter_latencies: Vec<u128> = Vec::new();

    for i in 0..1000 {
        let bpm = 70.0 + (i as f64 % 10.0);
        let start = Instant::now();
        let _filtered = filter.update(bpm);
        filter_latencies.push(start.elapsed().as_micros());
    }

    filter_latencies.sort_unstable();
    let filter_p95 = filter_latencies[(1000.0 * 0.95) as usize] as f64 / 1000.0;

    println!("Filter P95: {:.2}ms", filter_p95);

    // Stage 3: HRV calculation
    let rr_intervals = vec![800, 810, 820, 815, 805, 825];
    let mut hrv_latencies: Vec<u128> = Vec::new();

    for _ in 0..1000 {
        let start = Instant::now();
        let _rmssd = calculate_rmssd(&rr_intervals);
        hrv_latencies.push(start.elapsed().as_micros());
    }

    hrv_latencies.sort_unstable();
    let hrv_p95 = hrv_latencies[(1000.0 * 0.95) as usize] as f64 / 1000.0;

    println!("HRV P95: {:.2}ms", hrv_p95);
    println!("================================\n");

    // Individual stages should be very fast (< 1ms each)
    assert!(
        parse_p95 < 1.0,
        "Parse P95 ({:.2}ms) should be < 1ms",
        parse_p95
    );
    assert!(
        filter_p95 < 1.0,
        "Filter P95 ({:.2}ms) should be < 1ms",
        filter_p95
    );
    assert!(hrv_p95 < 1.0, "HRV P95 ({:.2}ms) should be < 1ms", hrv_p95);
}
