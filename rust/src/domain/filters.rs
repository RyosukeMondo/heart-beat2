//! Signal processing filters for heart rate data.
//!
//! This module provides filtering capabilities to reduce noise in heart rate measurements
//! using Kalman filtering techniques.

use kalman_filters::{KalmanFilter as KF, KalmanFilterBuilder};

/// Minimum physiologically plausible heart rate in BPM.
const MIN_VALID_BPM: u16 = 30;

/// Maximum physiologically plausible heart rate in BPM.
const MAX_VALID_BPM: u16 = 220;

/// Checks if a heart rate value is physiologically plausible.
///
/// Rejects sensor artifacts and impossible values before filtering.
/// The valid range is 30-220 BPM, which covers:
/// - Resting heart rates for trained athletes (~30-40 BPM)
/// - Maximum heart rates during extreme exertion (~220 BPM)
///
/// Values outside this range are considered sensor artifacts or errors.
///
/// # Parameters
///
/// - `bpm`: The heart rate measurement to validate
///
/// # Returns
///
/// `true` if the heart rate is within the valid physiological range (30-220 BPM),
/// `false` otherwise.
///
/// # Examples
///
/// ```
/// use heart_beat::domain::filters::is_valid_bpm;
///
/// assert!(is_valid_bpm(70));  // Normal resting HR
/// assert!(is_valid_bpm(180)); // High exercise HR
/// assert!(!is_valid_bpm(250)); // Impossible
/// assert!(!is_valid_bpm(20));  // Too low
/// ```
pub fn is_valid_bpm(bpm: u16) -> bool {
    (MIN_VALID_BPM..=MAX_VALID_BPM).contains(&bpm)
}

/// A Kalman filter wrapper configured for heart rate tracking.
///
/// This filter reduces measurement noise while tracking heart rate changes.
/// It uses a 1-dimensional Kalman filter with parameters tuned for heart rate signals:
/// - Process noise: 0.1 (how much we expect HR to change between measurements)
/// - Measurement noise: 2.0 (expected sensor noise in BPM)
///
/// # Examples
///
/// ```
/// use heart_beat::domain::filters::KalmanFilter;
///
/// let mut filter = KalmanFilter::new(0.1, 2.0);
/// let filtered_bpm = filter.update(75.0);
/// ```
pub struct KalmanFilter {
    kalman: KF<f64>,
}

impl KalmanFilter {
    /// Creates a new Kalman filter with specified noise parameters.
    ///
    /// # Parameters
    ///
    /// - `process_noise`: Expected variance in heart rate changes (default: 0.1)
    /// - `measurement_noise`: Expected sensor noise variance (default: 2.0)
    ///
    /// # Parameter Rationale
    ///
    /// - Process noise of 0.1: Heart rate changes gradually in normal conditions.
    ///   This low value assumes HR doesn't jump wildly between measurements.
    /// - Measurement noise of 2.0: BLE HR sensors typically have ~±2 BPM accuracy.
    ///   This reflects the expected measurement uncertainty.
    pub fn new(process_noise: f64, measurement_noise: f64) -> Self {
        let kalman = KalmanFilterBuilder::new(1, 1)
            .initial_state(vec![70.0]) // Initial guess: typical resting HR
            .initial_covariance(vec![10.0]) // Initial uncertainty
            .transition_matrix(vec![1.0]) // State doesn't change without input
            .process_noise(vec![process_noise])
            .observation_matrix(vec![1.0]) // Directly observe the state
            .measurement_noise(vec![measurement_noise])
            .build()
            .expect("Failed to build Kalman filter with valid 1D parameters");

        Self { kalman }
    }


    /// Updates the filter with a new heart rate measurement and returns the filtered value.
    ///
    /// # Parameters
    ///
    /// - `measurement`: The raw heart rate measurement in BPM
    ///
    /// # Returns
    ///
    /// The filtered heart rate estimate in BPM
    ///
    /// # Examples
    ///
    /// ```
    /// use heart_beat::domain::filters::KalmanFilter;
    ///
    /// let mut filter = KalmanFilter::default();
    /// let raw_bpm = 75.0;
    /// let filtered_bpm = filter.update(raw_bpm);
    /// assert!((filtered_bpm - raw_bpm).abs() < 5.0); // Filter stays close to measurement
    /// ```
    pub fn update(&mut self, measurement: f64) -> f64 {
        // Predict step (no control input)
        self.kalman.predict();

        // Update step with measurement
        self.kalman
            .update(&[measurement])
            .expect("Update should succeed with valid 1D measurement");

        // Return the filtered state estimate (first element of state vector)
        self.kalman.state()[0]
    }

    /// Updates the filter only if the measurement is physiologically valid.
    ///
    /// If the measurement is invalid (outside 30-220 BPM range), the filter state
    /// is preserved and the method returns the current filtered estimate without
    /// incorporating the invalid measurement. This prevents sensor artifacts from
    /// corrupting the filter state.
    ///
    /// # Parameters
    ///
    /// - `measurement`: The raw heart rate measurement in BPM
    ///
    /// # Returns
    ///
    /// The filtered heart rate estimate in BPM. If the measurement was valid,
    /// returns the updated estimate. If invalid, returns the previous estimate.
    ///
    /// # Examples
    ///
    /// ```
    /// use heart_beat::domain::filters::KalmanFilter;
    ///
    /// let mut filter = KalmanFilter::default();
    ///
    /// // Valid measurements update the filter
    /// let filtered1 = filter.filter_if_valid(75.0);
    /// let filtered2 = filter.filter_if_valid(76.0);
    ///
    /// // Invalid measurement is rejected, filter state preserved
    /// let filtered3 = filter.filter_if_valid(250.0);
    /// assert_eq!(filtered2, filtered3); // State unchanged
    /// ```
    pub fn filter_if_valid(&mut self, measurement: f64) -> f64 {
        let bpm = measurement.round() as u16;

        if is_valid_bpm(bpm) {
            // Measurement is valid, update the filter
            self.update(measurement)
        } else {
            // Measurement is invalid, return current estimate without updating
            self.kalman.state()[0]
        }
    }
}

impl Default for KalmanFilter {
    /// Creates a new Kalman filter with default parameters optimized for heart rate tracking.
    ///
    /// Uses process_noise=0.1 and measurement_noise=2.0, which provide good noise reduction
    /// while tracking step changes in heart rate (e.g., during exercise transitions).
    fn default() -> Self {
        Self::new(0.1, 2.0)
    }
}

#[cfg(test)]
#[allow(clippy::useless_vec)]
mod tests {
    use super::*;

    #[test]
    fn test_filter_smooths_noisy_input() {
        let mut filter = KalmanFilter::default();

        // Simulate noisy measurements around 75 BPM
        let measurements = vec![75.0, 77.0, 73.0, 76.0, 74.0, 75.0];
        let mut filtered_values = Vec::new();

        for m in measurements.iter() {
            filtered_values.push(filter.update(*m));
        }

        // After a few measurements, the filtered value should converge toward the mean
        let last_filtered = filtered_values.last().unwrap();
        assert!((last_filtered - 75.0).abs() < 2.0, "Filter should converge to ~75 BPM");
    }

    #[test]
    fn test_filter_tracks_step_change() {
        let mut filter = KalmanFilter::default();

        // Initialize filter at resting HR
        for _ in 0..10 {
            filter.update(70.0);
        }

        // Simulate sudden exercise increase
        let mut final_filtered = 0.0;
        for _ in 0..20 {
            final_filtered = filter.update(140.0);
        }

        // Filter should eventually track to new level
        // After 20 measurements, should be close to 140
        assert!(final_filtered > 120.0, "Filter should track step changes, got {}", final_filtered);
    }

    #[test]
    fn test_custom_parameters() {
        // Test with different noise parameters
        let mut filter = KalmanFilter::new(0.5, 5.0);
        let filtered = filter.update(75.0);

        // Just verify it doesn't panic and returns a reasonable value
        assert!(filtered > 0.0 && filtered < 300.0);
    }

    #[test]
    fn test_filter_state_preservation() {
        let mut filter = KalmanFilter::default();

        // Feed several measurements
        filter.update(70.0);
        filter.update(72.0);
        let filtered1 = filter.update(71.0);

        // Next update should be influenced by previous state
        let filtered2 = filter.update(71.0);

        // Second update with same value should be closer to 71
        assert!((filtered2 - 71.0).abs() < (filtered1 - 71.0).abs() ||
                (filtered2 - 71.0).abs() < 1.0);
    }

    #[test]
    fn test_is_valid_bpm_normal_range() {
        // Test valid normal resting heart rates
        assert!(is_valid_bpm(60));
        assert!(is_valid_bpm(70));
        assert!(is_valid_bpm(80));
        assert!(is_valid_bpm(90));
    }

    #[test]
    fn test_is_valid_bpm_athletic_range() {
        // Test valid athletic resting heart rates (lower)
        assert!(is_valid_bpm(30));
        assert!(is_valid_bpm(40));
        assert!(is_valid_bpm(50));
    }

    #[test]
    fn test_is_valid_bpm_exercise_range() {
        // Test valid exercise heart rates (higher)
        assert!(is_valid_bpm(150));
        assert!(is_valid_bpm(180));
        assert!(is_valid_bpm(200));
        assert!(is_valid_bpm(220));
    }

    #[test]
    fn test_is_valid_bpm_boundary_values() {
        // Test boundary conditions
        assert!(is_valid_bpm(30));  // Minimum valid
        assert!(is_valid_bpm(220)); // Maximum valid
        assert!(!is_valid_bpm(29)); // Just below minimum
        assert!(!is_valid_bpm(221)); // Just above maximum
    }

    #[test]
    fn test_is_valid_bpm_invalid_low() {
        // Test clearly invalid low values
        assert!(!is_valid_bpm(0));
        assert!(!is_valid_bpm(10));
        assert!(!is_valid_bpm(20));
        assert!(!is_valid_bpm(29));
    }

    #[test]
    fn test_is_valid_bpm_invalid_high() {
        // Test clearly invalid high values
        assert!(!is_valid_bpm(221));
        assert!(!is_valid_bpm(250));
        assert!(!is_valid_bpm(300));
        assert!(!is_valid_bpm(500));
    }

    #[test]
    fn test_filter_if_valid_accepts_valid_measurement() {
        let mut filter = KalmanFilter::default();

        // First update to establish a baseline
        filter.update(70.0);

        // Valid measurement should be processed
        let filtered = filter.filter_if_valid(75.0);

        // Filter should have been updated (filtered value should be influenced by new measurement)
        assert!(filtered > 70.0 && filtered < 80.0);
    }

    #[test]
    fn test_filter_if_valid_rejects_invalid_high() {
        let mut filter = KalmanFilter::default();

        // Establish baseline
        filter.update(70.0);
        filter.update(72.0);
        let baseline = filter.update(71.0);

        // Invalid high measurement should be rejected
        let filtered = filter.filter_if_valid(250.0);

        // State should be preserved (approximately equal to baseline)
        assert!((filtered - baseline).abs() < 0.1);
    }

    #[test]
    fn test_filter_if_valid_rejects_invalid_low() {
        let mut filter = KalmanFilter::default();

        // Establish baseline
        filter.update(70.0);
        filter.update(72.0);
        let baseline = filter.update(71.0);

        // Invalid low measurement should be rejected
        let filtered = filter.filter_if_valid(20.0);

        // State should be preserved (approximately equal to baseline)
        assert!((filtered - baseline).abs() < 0.1);
    }

    #[test]
    fn test_filter_if_valid_boundary_values() {
        let mut filter = KalmanFilter::default();

        // Establish baseline
        filter.update(70.0);

        // Boundary valid values should be accepted
        let filtered_min = filter.filter_if_valid(30.0);
        assert!(filtered_min < 70.0); // Should move toward 30

        filter.update(70.0); // Reset

        let filtered_max = filter.filter_if_valid(220.0);
        assert!(filtered_max > 70.0); // Should move toward 220
    }

    #[test]
    fn test_filter_if_valid_mixed_valid_invalid() {
        let mut filter = KalmanFilter::default();

        // Mix of valid and invalid measurements
        let f1 = filter.filter_if_valid(70.0);  // Valid
        let f2 = filter.filter_if_valid(250.0); // Invalid - should be rejected
        let f3 = filter.filter_if_valid(72.0);  // Valid

        // f2 should be approximately equal to f1 (state preserved)
        assert!((f2 - f1).abs() < 0.1);

        // f3 should incorporate the second valid measurement
        assert!(f3 > f1 && f3 < 75.0);
    }

    #[test]
    fn test_filter_if_valid_preserves_state_across_multiple_invalid() {
        let mut filter = KalmanFilter::default();

        // Establish baseline with valid measurements
        filter.update(70.0);
        filter.update(71.0);
        let baseline = filter.update(72.0);

        // Multiple invalid measurements in a row
        let f1 = filter.filter_if_valid(300.0);
        let f2 = filter.filter_if_valid(10.0);
        let f3 = filter.filter_if_valid(250.0);

        // All should return approximately the same value (baseline)
        assert!((f1 - baseline).abs() < 0.1);
        assert!((f2 - baseline).abs() < 0.1);
        assert!((f3 - baseline).abs() < 0.1);

        // Next valid measurement should still work
        let f4 = filter.filter_if_valid(75.0);
        assert!(f4 > baseline && f4 < 76.0);
    }
}
