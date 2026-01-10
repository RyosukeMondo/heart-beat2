//! Heart Rate Variability (HRV) calculation module.
//!
//! This module provides functions for calculating HRV metrics from RR-intervals
//! extracted from Bluetooth heart rate monitors. HRV metrics are useful for
//! assessing stress, recovery, and autonomic nervous system function.

use cardio_rs::metrics::time_domain::TimeMetrics;

/// Calculates RMSSD (Root Mean Square of Successive Differences) from RR-intervals.
///
/// RMSSD is a time-domain HRV metric that measures short-term heart rate variability.
/// It represents the square root of the mean of the squares of successive differences
/// between adjacent RR-intervals. Higher RMSSD values generally indicate better
/// parasympathetic (rest-and-digest) nervous system activity.
///
/// # Arguments
///
/// * `rr_intervals` - Slice of RR-intervals in 1/1024 second resolution, as provided
///   by Bluetooth heart rate monitors following the Heart Rate Service specification.
///
/// # Returns
///
/// * `Some(f64)` - RMSSD value in milliseconds if calculation is successful
/// * `None` - If there are fewer than 2 intervals (minimum required for RMSSD)
///   or if any intervals are outside the physiologically valid range (300-2000 ms)
///
/// # Examples
///
/// ```
/// use heart_beat::domain::hrv::calculate_rmssd;
///
/// // RR-intervals: 800ms, 820ms, 810ms (in 1/1024s units)
/// let rr_intervals = vec![819, 839, 829]; // 819 * 1000 / 1024 ≈ 800ms
/// let rmssd = calculate_rmssd(&rr_intervals);
/// assert!(rmssd.is_some());
/// ```
///
/// # Validation
///
/// The function validates that all RR-intervals fall within the physiologically
/// plausible range of 300-2000 milliseconds. This range covers:
/// - Minimum: 300ms corresponds to ~200 BPM (maximum sustainable heart rate)
/// - Maximum: 2000ms corresponds to ~30 BPM (minimum resting heart rate)
///
/// Intervals outside this range are likely sensor artifacts and cause the function
/// to return `None`.
pub fn calculate_rmssd(rr_intervals: &[u16]) -> Option<f64> {
    // Need at least 2 intervals to calculate successive differences
    if rr_intervals.len() < 2 {
        return None;
    }

    // Convert from 1/1024 second units to milliseconds
    // Formula: ms = (value * 1000) / 1024
    let rr_ms: Vec<f64> = rr_intervals
        .iter()
        .map(|&rr| (rr as f64 * 1000.0) / 1024.0)
        .collect();

    // Validate that all intervals are physiologically plausible
    // Valid range: 300ms (200 BPM) to 2000ms (30 BPM)
    const MIN_RR_MS: f64 = 300.0;
    const MAX_RR_MS: f64 = 2000.0;

    for &rr in &rr_ms {
        if rr < MIN_RR_MS || rr > MAX_RR_MS {
            return None;
        }
    }

    // Use cardio-rs to compute time-domain metrics
    let metrics = TimeMetrics::compute(&rr_ms);

    // Return the RMSSD value
    Some(metrics.rmssd)
}

/// Calculates SDNN (Standard Deviation of NN intervals) from RR-intervals.
///
/// SDNN is a time-domain HRV metric that measures overall heart rate variability.
/// It represents the standard deviation of all RR-intervals in the measurement
/// period. SDNN reflects both short-term and long-term variability.
///
/// # Arguments
///
/// * `rr_intervals` - Slice of RR-intervals in 1/1024 second resolution
///
/// # Returns
///
/// * `Some(f64)` - SDNN value in milliseconds if calculation is successful
/// * `None` - If there are fewer than 2 intervals or if any intervals are
///   outside the physiologically valid range (300-2000 ms)
///
/// # Examples
///
/// ```
/// use heart_beat::domain::hrv::calculate_sdnn;
///
/// let rr_intervals = vec![819, 839, 829, 815, 825];
/// let sdnn = calculate_sdnn(&rr_intervals);
/// assert!(sdnn.is_some());
/// ```
pub fn calculate_sdnn(rr_intervals: &[u16]) -> Option<f64> {
    // Need at least 2 intervals for meaningful standard deviation
    if rr_intervals.len() < 2 {
        return None;
    }

    // Convert from 1/1024 second units to milliseconds
    let rr_ms: Vec<f64> = rr_intervals
        .iter()
        .map(|&rr| (rr as f64 * 1000.0) / 1024.0)
        .collect();

    // Validate physiological range
    const MIN_RR_MS: f64 = 300.0;
    const MAX_RR_MS: f64 = 2000.0;

    for &rr in &rr_ms {
        if rr < MIN_RR_MS || rr > MAX_RR_MS {
            return None;
        }
    }

    // Use cardio-rs to compute time-domain metrics
    let metrics = TimeMetrics::compute(&rr_ms);

    // Return the SDNN value
    Some(metrics.sdnn)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_calculate_rmssd_basic() {
        // Test with known RR-intervals
        // Using intervals around 800ms (typical resting HR ~75 BPM)
        // 819 * 1000 / 1024 = 800.0 ms
        // 839 * 1000 / 1024 = 819.5 ms
        // 829 * 1000 / 1024 = 809.8 ms
        let rr_intervals = vec![819, 839, 829, 815, 825];
        let rmssd = calculate_rmssd(&rr_intervals);

        assert!(rmssd.is_some());
        let rmssd_value = rmssd.unwrap();
        // RMSSD should be positive and reasonable for these intervals
        assert!(rmssd_value > 0.0);
        assert!(rmssd_value < 100.0); // Typical RMSSD range is 20-100ms
    }

    #[test]
    fn test_calculate_rmssd_insufficient_intervals() {
        // Need at least 2 intervals
        let rr_intervals = vec![819];
        assert_eq!(calculate_rmssd(&rr_intervals), None);

        let rr_intervals_empty: Vec<u16> = vec![];
        assert_eq!(calculate_rmssd(&rr_intervals_empty), None);
    }

    #[test]
    fn test_calculate_rmssd_out_of_range_too_low() {
        // 200 * 1000 / 1024 = 195.3ms (too low, > 307 BPM)
        let rr_intervals = vec![200, 205, 210];
        assert_eq!(calculate_rmssd(&rr_intervals), None);
    }

    #[test]
    fn test_calculate_rmssd_out_of_range_too_high() {
        // 2100 * 1000 / 1024 = 2050.8ms (too high, < 29 BPM)
        let rr_intervals = vec![2100, 2110, 2105];
        assert_eq!(calculate_rmssd(&rr_intervals), None);
    }

    #[test]
    fn test_calculate_rmssd_edge_cases_valid() {
        // Test at the boundaries of valid range
        // 308 * 1000 / 1024 ≈ 300.8ms (just above 300ms min)
        // 2048 * 1000 / 1024 = 2000ms (exactly at 30 BPM max)
        let rr_intervals = vec![308, 2048, 1024];
        let rmssd = calculate_rmssd(&rr_intervals);
        assert!(rmssd.is_some());
    }

    #[test]
    fn test_calculate_rmssd_realistic_resting() {
        // Realistic resting heart rate ~70 BPM
        // RR interval ≈ 857ms → 857 * 1024 / 1000 ≈ 877
        let rr_intervals = vec![877, 882, 870, 885, 873, 880];
        let rmssd = calculate_rmssd(&rr_intervals);

        assert!(rmssd.is_some());
        let rmssd_value = rmssd.unwrap();
        // Typical resting RMSSD is 20-80ms
        assert!(rmssd_value > 0.0);
        assert!(rmssd_value < 200.0);
    }

    #[test]
    fn test_calculate_sdnn_basic() {
        let rr_intervals = vec![819, 839, 829, 815, 825];
        let sdnn = calculate_sdnn(&rr_intervals);

        assert!(sdnn.is_some());
        let sdnn_value = sdnn.unwrap();
        assert!(sdnn_value > 0.0);
        assert!(sdnn_value < 200.0); // Typical SDNN range
    }

    #[test]
    fn test_calculate_sdnn_insufficient_intervals() {
        let rr_intervals = vec![819];
        assert_eq!(calculate_sdnn(&rr_intervals), None);
    }

    #[test]
    fn test_calculate_sdnn_out_of_range() {
        let rr_intervals = vec![200, 205, 210];
        assert_eq!(calculate_sdnn(&rr_intervals), None);
    }

    #[test]
    fn test_rmssd_vs_sdnn_values() {
        // RMSSD and SDNN should both return valid values but differ
        let rr_intervals = vec![819, 839, 829, 815, 825, 835, 820];
        let rmssd = calculate_rmssd(&rr_intervals).unwrap();
        let sdnn = calculate_sdnn(&rr_intervals).unwrap();

        // Both should be positive
        assert!(rmssd > 0.0);
        assert!(sdnn > 0.0);

        // They measure different aspects so values will differ
        // RMSSD focuses on successive differences, SDNN on overall variation
    }

    #[test]
    fn test_conversion_accuracy() {
        // Test unit conversion: 1024 units = 1000ms
        // 1024 * 1000 / 1024 = 1000ms exactly
        let rr_intervals = vec![1024, 1024, 1024];
        let rmssd = calculate_rmssd(&rr_intervals);

        assert!(rmssd.is_some());
        // With identical intervals, RMSSD should be 0
        assert!((rmssd.unwrap()).abs() < 0.01);
    }

    #[test]
    fn test_mixed_valid_and_invalid() {
        // One invalid interval should fail the whole calculation
        let rr_intervals = vec![819, 839, 2200, 829]; // 2200 is out of range
        assert_eq!(calculate_rmssd(&rr_intervals), None);
    }
}
