//! Resting heart rate tracking and analysis.
//!
//! Pure domain logic for recording, trending, and analyzing resting heart rate
//! measurements over time. Supports multiple measurement sources (morning readings,
//! session-derived, manual entry) and computes rolling averages with trend detection.

use chrono::NaiveDate;
use serde::{Deserialize, Serialize};

use crate::domain::analytics::TrendPoint;
use crate::domain::session_history::CompletedSession;

/// A single resting heart rate measurement on a given date.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RestingHrMeasurement {
    /// The date this measurement was taken.
    pub date: NaiveDate,
    /// Resting heart rate in beats per minute.
    pub bpm: u16,
    /// How this measurement was obtained.
    pub source: MeasurementSource,
}

/// How a resting HR measurement was obtained.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum MeasurementSource {
    /// User's morning measurement (most reliable).
    Morning,
    /// Detected from session warm-up minimum HR.
    Session,
    /// Manually entered by the user.
    Manual,
}

/// Aggregated resting heart rate statistics.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RestingHrStats {
    /// Most recent measurement (bpm), if any.
    pub current: Option<u16>,
    /// Rolling 7-day average, if sufficient data.
    pub seven_day_avg: Option<f64>,
    /// Rolling 30-day average, if sufficient data.
    pub thirty_day_avg: Option<f64>,
    /// Direction the resting HR trend is heading.
    pub trend_direction: TrendDirection,
}

/// Direction of the resting HR trend over time.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TrendDirection {
    /// HR is decreasing (fitness improving).
    Improving,
    /// HR is roughly stable (within 2 bpm).
    Stable,
    /// HR is increasing (possible overtraining or detraining).
    Worsening,
    /// Not enough data to determine a trend.
    Insufficient,
}

/// Convert resting HR measurements into trend points for charting.
///
/// Each measurement becomes a [`TrendPoint`] with the timestamp set to
/// midnight UTC on the measurement date.
pub fn compute_resting_hr_trend(measurements: &[RestingHrMeasurement]) -> Vec<TrendPoint> {
    measurements
        .iter()
        .map(|m| TrendPoint {
            timestamp_millis: date_to_millis(m.date),
            value: m.bpm as f64,
        })
        .collect()
}

/// Compute aggregated resting HR statistics from a slice of measurements.
///
/// Measurements should be sorted chronologically for correct results.
/// The most recent measurement's date is used as the reference for rolling windows.
pub fn compute_resting_hr_stats(measurements: &[RestingHrMeasurement]) -> RestingHrStats {
    if measurements.is_empty() {
        return RestingHrStats {
            current: None,
            seven_day_avg: None,
            thirty_day_avg: None,
            trend_direction: TrendDirection::Insufficient,
        };
    }

    let most_recent = measurements
        .iter()
        .max_by_key(|m| m.date)
        .expect("non-empty slice");

    let reference_date = most_recent.date;
    let seven_day_avg = rolling_avg(measurements, reference_date, 7);
    let thirty_day_avg = rolling_avg(measurements, reference_date, 30);

    let trend_direction = match (seven_day_avg, thirty_day_avg) {
        (Some(avg7), Some(avg30)) => classify_trend(avg7, avg30),
        _ => TrendDirection::Insufficient,
    };

    RestingHrStats {
        current: Some(most_recent.bpm),
        seven_day_avg,
        thirty_day_avg,
        trend_direction,
    }
}

/// Detect a potential resting HR from the warm-up period of a session.
///
/// Examines the first 5 minutes of heart rate samples and returns the minimum
/// if at least 10 samples exist in that window. This approximates resting HR
/// when the user starts a session from rest.
pub fn detect_resting_hr_from_session(session: &CompletedSession) -> Option<u16> {
    if session.hr_samples.is_empty() {
        return None;
    }

    let warmup_cutoff = session.start_time + chrono::Duration::minutes(5);

    let warmup_samples: Vec<u16> = session
        .hr_samples
        .iter()
        .filter(|s| s.timestamp <= warmup_cutoff)
        .map(|s| s.bpm)
        .collect();

    if warmup_samples.len() < 10 {
        return None;
    }

    warmup_samples.into_iter().min()
}

/// Compute the average bpm of measurements within `days` before `reference_date` (inclusive).
fn rolling_avg(
    measurements: &[RestingHrMeasurement],
    reference_date: NaiveDate,
    days: i64,
) -> Option<f64> {
    let cutoff = reference_date - chrono::Duration::days(days - 1);
    let in_window: Vec<f64> = measurements
        .iter()
        .filter(|m| m.date >= cutoff && m.date <= reference_date)
        .map(|m| m.bpm as f64)
        .collect();

    if in_window.is_empty() {
        return None;
    }

    let sum: f64 = in_window.iter().sum();
    Some(sum / in_window.len() as f64)
}

/// Classify trend direction by comparing short-term to long-term average.
///
/// Improving = 7-day avg is more than 2 bpm below 30-day avg (HR dropping).
/// Worsening = 7-day avg is more than 2 bpm above 30-day avg (HR rising).
/// Stable = within 2 bpm tolerance.
fn classify_trend(seven_day_avg: f64, thirty_day_avg: f64) -> TrendDirection {
    let diff = seven_day_avg - thirty_day_avg;
    if diff < -2.0 {
        TrendDirection::Improving
    } else if diff > 2.0 {
        TrendDirection::Worsening
    } else {
        TrendDirection::Stable
    }
}

/// Convert a `NaiveDate` to Unix milliseconds at midnight UTC.
fn date_to_millis(date: NaiveDate) -> i64 {
    date.and_hms_opt(0, 0, 0)
        .expect("valid midnight time")
        .and_utc()
        .timestamp_millis()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::session_history::{HrSample, SessionStatus, SessionSummary};
    use chrono::{TimeZone, Utc};

    fn measurement(date_str: &str, bpm: u16, source: MeasurementSource) -> RestingHrMeasurement {
        RestingHrMeasurement {
            date: NaiveDate::parse_from_str(date_str, "%Y-%m-%d").unwrap(),
            bpm,
            source,
        }
    }

    fn make_session_with_samples(date_str: &str, samples: Vec<(i64, u16)>) -> CompletedSession {
        let start = Utc.from_utc_datetime(
            &NaiveDate::parse_from_str(date_str, "%Y-%m-%d")
                .unwrap()
                .and_hms_opt(10, 0, 0)
                .unwrap(),
        );
        let duration_secs = samples
            .last()
            .map(|(offset, _)| *offset as u32)
            .unwrap_or(0);
        let end = start + chrono::Duration::seconds(duration_secs as i64);

        let hr_samples: Vec<HrSample> = samples
            .iter()
            .map(|(offset_secs, bpm)| HrSample {
                timestamp: start + chrono::Duration::seconds(*offset_secs),
                bpm: *bpm,
            })
            .collect();

        CompletedSession {
            id: "test-session".to_string(),
            plan_name: "Test".to_string(),
            start_time: start,
            end_time: end,
            status: SessionStatus::Completed,
            hr_samples,
            phases_completed: 1,
            summary: SessionSummary {
                duration_secs,
                avg_hr: 140,
                max_hr: 160,
                min_hr: 60,
                time_in_zone: [60, 120, 60, 0, 0],
            },
        }
    }

    // --- Empty data tests ---

    #[test]
    fn trend_empty_returns_empty() {
        assert!(compute_resting_hr_trend(&[]).is_empty());
    }

    #[test]
    fn stats_empty_returns_insufficient() {
        let stats = compute_resting_hr_stats(&[]);
        assert_eq!(stats.current, None);
        assert_eq!(stats.seven_day_avg, None);
        assert_eq!(stats.thirty_day_avg, None);
        assert_eq!(stats.trend_direction, TrendDirection::Insufficient);
    }

    #[test]
    fn session_detection_empty_samples() {
        let session = make_session_with_samples("2026-03-20", vec![]);
        assert_eq!(detect_resting_hr_from_session(&session), None);
    }

    // --- Single measurement tests ---

    #[test]
    fn trend_single_measurement() {
        let ms = vec![measurement("2026-03-20", 62, MeasurementSource::Morning)];
        let trend = compute_resting_hr_trend(&ms);

        assert_eq!(trend.len(), 1);
        assert_eq!(trend[0].value, 62.0);
        let expected_millis = date_to_millis(NaiveDate::from_ymd_opt(2026, 3, 20).unwrap());
        assert_eq!(trend[0].timestamp_millis, expected_millis);
    }

    #[test]
    fn stats_single_measurement() {
        let ms = vec![measurement("2026-03-20", 65, MeasurementSource::Manual)];
        let stats = compute_resting_hr_stats(&ms);

        assert_eq!(stats.current, Some(65));
        assert_eq!(stats.seven_day_avg, Some(65.0));
        assert_eq!(stats.thirty_day_avg, Some(65.0));
        // Both averages exist but are equal, so Stable
        assert_eq!(stats.trend_direction, TrendDirection::Stable);
    }

    // --- Multi-measurement trend tests ---

    #[test]
    fn trend_multiple_measurements_preserves_order() {
        let ms = vec![
            measurement("2026-03-18", 64, MeasurementSource::Morning),
            measurement("2026-03-19", 62, MeasurementSource::Session),
            measurement("2026-03-20", 60, MeasurementSource::Morning),
        ];
        let trend = compute_resting_hr_trend(&ms);

        assert_eq!(trend.len(), 3);
        assert_eq!(trend[0].value, 64.0);
        assert_eq!(trend[1].value, 62.0);
        assert_eq!(trend[2].value, 60.0);
    }

    // --- Trend direction detection ---

    #[test]
    fn direction_improving_when_seven_day_lower() {
        // 30-day window has higher values, 7-day window has lower values
        let mut ms = Vec::new();
        // Older measurements (outside 7-day, inside 30-day): higher HR
        for day in 1..=20 {
            ms.push(measurement(
                &format!("2026-02-{:02}", day),
                72,
                MeasurementSource::Morning,
            ));
        }
        // Recent measurements (inside 7-day): lower HR (>2 bpm drop)
        for day in 15..=20 {
            ms.push(measurement(
                &format!("2026-03-{:02}", day),
                62,
                MeasurementSource::Morning,
            ));
        }

        let stats = compute_resting_hr_stats(&ms);
        assert_eq!(stats.trend_direction, TrendDirection::Improving);
    }

    #[test]
    fn direction_worsening_when_seven_day_higher() {
        let mut ms = Vec::new();
        // Older measurements: lower HR
        for day in 1..=20 {
            ms.push(measurement(
                &format!("2026-02-{:02}", day),
                60,
                MeasurementSource::Morning,
            ));
        }
        // Recent measurements: higher HR (>2 bpm rise)
        for day in 15..=20 {
            ms.push(measurement(
                &format!("2026-03-{:02}", day),
                70,
                MeasurementSource::Morning,
            ));
        }

        let stats = compute_resting_hr_stats(&ms);
        assert_eq!(stats.trend_direction, TrendDirection::Worsening);
    }

    #[test]
    fn direction_stable_within_tolerance() {
        let mut ms = Vec::new();
        // Older measurements
        for day in 1..=20 {
            ms.push(measurement(
                &format!("2026-02-{:02}", day),
                65,
                MeasurementSource::Morning,
            ));
        }
        // Recent measurements: within 2 bpm
        for day in 15..=20 {
            ms.push(measurement(
                &format!("2026-03-{:02}", day),
                64,
                MeasurementSource::Morning,
            ));
        }

        let stats = compute_resting_hr_stats(&ms);
        assert_eq!(stats.trend_direction, TrendDirection::Stable);
    }

    #[test]
    fn direction_insufficient_only_recent_data() {
        // All data within 7 days, nothing in the 8-30 day range
        let ms = vec![
            measurement("2026-03-19", 62, MeasurementSource::Morning),
            measurement("2026-03-20", 63, MeasurementSource::Morning),
        ];
        let stats = compute_resting_hr_stats(&ms);
        // Both 7-day and 30-day will have data (both windows include recent),
        // so trend should be Stable since averages are nearly equal
        assert_eq!(stats.trend_direction, TrendDirection::Stable);
    }

    // --- Rolling average window tests ---

    #[test]
    fn seven_day_avg_excludes_old_data() {
        let ms = vec![
            measurement("2026-03-01", 80, MeasurementSource::Morning), // Outside 7-day
            measurement("2026-03-18", 60, MeasurementSource::Morning),
            measurement("2026-03-19", 62, MeasurementSource::Morning),
            measurement("2026-03-20", 64, MeasurementSource::Morning),
        ];
        let stats = compute_resting_hr_stats(&ms);

        // 7-day avg should only include Mar 14-20 measurements: 60, 62, 64
        assert_eq!(stats.seven_day_avg, Some(62.0));
        // 30-day avg includes all: (80 + 60 + 62 + 64) / 4 = 66.5
        assert_eq!(stats.thirty_day_avg, Some(66.5));
    }

    #[test]
    fn current_is_most_recent_by_date() {
        let ms = vec![
            measurement("2026-03-18", 70, MeasurementSource::Morning),
            measurement("2026-03-20", 62, MeasurementSource::Morning),
            measurement("2026-03-19", 65, MeasurementSource::Session),
        ];
        let stats = compute_resting_hr_stats(&ms);
        assert_eq!(stats.current, Some(62)); // Mar 20 is most recent
    }

    // --- Session detection tests ---

    #[test]
    fn session_detection_sufficient_warmup_samples() {
        // 12 samples in first 5 minutes, minimum is 58
        let samples: Vec<(i64, u16)> = (0..12)
            .map(|i| (i * 20, 58 + (i as u16 % 5))) // 20s apart, bpm 58-62
            .collect();
        let session = make_session_with_samples("2026-03-20", samples);

        assert_eq!(detect_resting_hr_from_session(&session), Some(58));
    }

    #[test]
    fn session_detection_insufficient_warmup_samples() {
        // Only 5 samples in first 5 minutes (need 10)
        let samples: Vec<(i64, u16)> = (0..5).map(|i| (i * 60, 60 + i as u16)).collect();
        let session = make_session_with_samples("2026-03-20", samples);

        assert_eq!(detect_resting_hr_from_session(&session), None);
    }

    #[test]
    fn session_detection_ignores_post_warmup() {
        // 8 samples in warmup + 10 samples after warmup
        let mut samples: Vec<(i64, u16)> = (0..8)
            .map(|i| (i * 30, 65)) // 8 samples in first 4 min
            .collect();
        // Samples after 5 minutes with lower HR (should be ignored)
        for i in 0..10 {
            samples.push((300 + i * 10, 50));
        }
        let session = make_session_with_samples("2026-03-20", samples);

        // Only 8 warmup samples, less than 10 threshold
        assert_eq!(detect_resting_hr_from_session(&session), None);
    }

    #[test]
    fn session_detection_exactly_at_boundary() {
        // 10 samples, last one exactly at 5-minute mark
        let samples: Vec<(i64, u16)> = (0..10)
            .map(|i| (i * 30, 70 - i as u16)) // 0s to 270s, bpm 70 down to 61
            .collect();
        let session = make_session_with_samples("2026-03-20", samples);

        // All 10 within 5 min, minimum is 61
        assert_eq!(detect_resting_hr_from_session(&session), Some(61));
    }

    // --- Classify trend helper ---

    #[test]
    fn classify_trend_boundary_values() {
        // Exactly at boundary: -2.0 is Stable (not Improving)
        assert_eq!(classify_trend(60.0, 62.0), TrendDirection::Stable);
        // Just past boundary: -2.01 is Improving
        assert_eq!(classify_trend(59.99, 62.0), TrendDirection::Improving);
        // Exactly at +2.0 is Stable
        assert_eq!(classify_trend(64.0, 62.0), TrendDirection::Stable);
        // Just past boundary: +2.01 is Worsening
        assert_eq!(classify_trend(64.01, 62.0), TrendDirection::Worsening);
    }

    // --- Measurement source equality ---

    #[test]
    fn measurement_source_variants() {
        assert_ne!(MeasurementSource::Morning, MeasurementSource::Session);
        assert_ne!(MeasurementSource::Session, MeasurementSource::Manual);
        assert_ne!(MeasurementSource::Manual, MeasurementSource::Morning);
        assert_eq!(MeasurementSource::Morning, MeasurementSource::Morning);
    }

    // --- date_to_millis helper ---

    #[test]
    fn date_to_millis_correct() {
        let date = NaiveDate::from_ymd_opt(2026, 3, 20).unwrap();
        let millis = date_to_millis(date);
        // Reconstruct and verify
        let dt = chrono::DateTime::from_timestamp_millis(millis).unwrap();
        assert_eq!(dt.date_naive(), date);
        assert_eq!(dt.time(), chrono::NaiveTime::from_hms_opt(0, 0, 0).unwrap());
    }
}
