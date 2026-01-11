use criterion::{black_box, criterion_group, criterion_main, Criterion};
use heart_beat::domain::filters::KalmanFilter;
use heart_beat::domain::heart_rate::parse_heart_rate;
use heart_beat::domain::hrv::calculate_rmssd;

/// Benchmark parsing a simple UINT8 heart rate packet without RR-intervals.
///
/// This represents the minimal parsing workload for basic HR monitors that
/// only report BPM values without HRV data.
fn bench_parse_heart_rate_simple(c: &mut Criterion) {
    // Flags: 0x06 = sensor contact detected, UINT8 format
    // BPM: 72
    let data = &[0x06, 72];

    c.bench_function("parse_heart_rate_simple", |b| {
        b.iter(|| parse_heart_rate(black_box(data)))
    });
}

/// Benchmark parsing a UINT8 packet with multiple RR-intervals.
///
/// This is the most common format for advanced HR monitors that provide
/// HRV data. Represents typical workload with 3 RR-intervals.
fn bench_parse_heart_rate_with_rr(c: &mut Criterion) {
    // Flags: 0x16 = sensor contact + RR-intervals present
    // BPM: 72
    // RR-intervals: 820, 830, 815 (typical resting HR variability)
    let data = &[
        0x16, 72, 0x34, 0x03, // RR: 820
        0x3E, 0x03, // RR: 830
        0x2F, 0x03, // RR: 815
    ];

    c.bench_function("parse_heart_rate_with_rr", |b| {
        b.iter(|| parse_heart_rate(black_box(data)))
    });
}

/// Benchmark parsing a complex packet with all optional fields.
///
/// Tests worst-case parsing performance with UINT8 BPM, energy expended,
/// and RR-intervals all present.
fn bench_parse_heart_rate_complex(c: &mut Criterion) {
    // Flags: 0x1E = sensor contact + energy expended + RR-intervals
    // BPM: 80
    // Energy: 500
    // RR-intervals: 750, 760, 745, 755, 748
    let data = &[
        0x1E, 80, 0xF4, 0x01, // Energy: 500
        0xEE, 0x02, // RR: 750
        0xF8, 0x02, // RR: 760
        0xE9, 0x02, // RR: 745
        0xF3, 0x02, // RR: 755
        0xEC, 0x02, // RR: 748
    ];

    c.bench_function("parse_heart_rate_complex", |b| {
        b.iter(|| parse_heart_rate(black_box(data)))
    });
}

/// Benchmark Kalman filter update with a single measurement.
///
/// This represents the core filtering operation applied to each BPM reading.
/// Critical for maintaining <100ms P95 latency requirement.
fn bench_kalman_filter_update(c: &mut Criterion) {
    let mut filter = KalmanFilter::default();

    c.bench_function("kalman_filter_update", |b| {
        b.iter(|| filter.update(black_box(75.0)))
    });
}

/// Benchmark Kalman filter update with validation.
///
/// Tests the `filter_if_valid` path which includes bounds checking.
/// Represents production code path.
fn bench_kalman_filter_with_validation(c: &mut Criterion) {
    let mut filter = KalmanFilter::default();

    c.bench_function("kalman_filter_with_validation", |b| {
        b.iter(|| filter.filter_if_valid(black_box(75.0)))
    });
}

/// Benchmark RMSSD calculation from RR-intervals.
///
/// HRV calculation is performed when RR-intervals are present in the packet.
/// Uses realistic resting HR intervals (~70 BPM).
fn bench_calculate_rmssd_short(c: &mut Criterion) {
    // 5 RR-intervals around 857ms (70 BPM)
    let rr_intervals = vec![877, 882, 870, 885, 873];

    c.bench_function("calculate_rmssd_short", |b| {
        b.iter(|| calculate_rmssd(black_box(&rr_intervals)))
    });
}

/// Benchmark RMSSD calculation with longer interval window.
///
/// Tests performance with a larger HRV window (20 intervals).
/// Represents accumulated intervals over several seconds.
fn bench_calculate_rmssd_long(c: &mut Criterion) {
    // 20 RR-intervals with realistic variability
    let rr_intervals = vec![
        877, 882, 870, 885, 873, 880, 875, 890, 868, 883, 878, 872, 888, 865, 895, 871, 879, 884,
        869, 881,
    ];

    c.bench_function("calculate_rmssd_long", |b| {
        b.iter(|| calculate_rmssd(black_box(&rr_intervals)))
    });
}

/// Benchmark the full pipeline: BLE packet → FilteredHeartRate output.
///
/// This is the critical path benchmark that must stay under 100ms P95 latency.
/// Simulates the complete data flow:
/// 1. Parse BLE packet
/// 2. Validate and filter BPM
/// 3. Calculate HRV metrics (if RR-intervals present)
///
/// Uses a realistic packet with all features enabled.
fn bench_full_pipeline(c: &mut Criterion) {
    let mut filter = KalmanFilter::default();

    // Realistic packet: UINT8 BPM + RR-intervals
    let data = &[
        0x16, 72, 0x34, 0x03, // RR: 820
        0x3E, 0x03, // RR: 830
        0x2F, 0x03, // RR: 815
    ];

    c.bench_function("full_pipeline", |b| {
        b.iter(|| {
            // Parse the packet
            let measurement = parse_heart_rate(black_box(data)).unwrap();

            // Filter the BPM value
            let filtered_bpm = filter.filter_if_valid(black_box(measurement.bpm as f64));

            // Calculate HRV if RR-intervals are present
            let rmssd = if !measurement.rr_intervals.is_empty() {
                calculate_rmssd(black_box(&measurement.rr_intervals))
            } else {
                None
            };

            // Simulate creating the output struct
            black_box((measurement.bpm, filtered_bpm as u16, rmssd))
        })
    });
}

/// Benchmark the full pipeline with simple packet (no RR-intervals).
///
/// Tests the fast path when HRV data is not available.
/// Should be faster than full_pipeline since it skips HRV calculation.
fn bench_full_pipeline_simple(c: &mut Criterion) {
    let mut filter = KalmanFilter::default();

    // Simple packet: just BPM, no RR-intervals
    let data = &[0x06, 72];

    c.bench_function("full_pipeline_simple", |b| {
        b.iter(|| {
            let measurement = parse_heart_rate(black_box(data)).unwrap();
            let filtered_bpm = filter.filter_if_valid(black_box(measurement.bpm as f64));
            black_box((measurement.bpm, filtered_bpm as u16))
        })
    });
}

criterion_group!(
    benches,
    bench_parse_heart_rate_simple,
    bench_parse_heart_rate_with_rr,
    bench_parse_heart_rate_complex,
    bench_kalman_filter_update,
    bench_kalman_filter_with_validation,
    bench_calculate_rmssd_short,
    bench_calculate_rmssd_long,
    bench_full_pipeline,
    bench_full_pipeline_simple,
);

criterion_main!(benches);
