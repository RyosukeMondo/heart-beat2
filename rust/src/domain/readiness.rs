//! Recovery and readiness score computation module.
//!
//! Pure domain logic for computing daily readiness scores from HRV, resting
//! heart rate, and training load data. Readiness scores help athletes decide
//! whether to train hard, go easy, or rest on a given day.

use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};

/// Weight of the HRV component in the final readiness score.
const HRV_WEIGHT: f64 = 0.40;
/// Weight of the resting heart rate component in the final readiness score.
const RHR_WEIGHT: f64 = 0.30;
/// Weight of the training load (TSB) component in the final readiness score.
const LOAD_WEIGHT: f64 = 0.30;

/// A single HRV measurement taken at a specific time.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct HrvReading {
    /// When the reading was taken.
    pub timestamp: DateTime<Utc>,
    /// Root mean square of successive differences, in milliseconds.
    pub rmssd: f64,
}

/// A single resting heart rate measurement.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RestingHrReading {
    /// When the reading was taken.
    pub timestamp: DateTime<Utc>,
    /// Resting heart rate in beats per minute.
    pub bpm: u16,
}

/// Categorical readiness level derived from the numeric score.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ReadinessLevel {
    /// Score >= 70: athlete is well-recovered and ready for hard training.
    Ready,
    /// Score >= 40 and < 70: moderate recovery, consider lighter training.
    Moderate,
    /// Score < 40: fatigued, prioritize rest and recovery.
    Rest,
}

/// Composite readiness score with component breakdown.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ReadinessScore {
    /// Overall readiness score from 0 (completely fatigued) to 100 (fully recovered).
    pub score: u8,
    /// Categorical readiness level.
    pub level: ReadinessLevel,
    /// HRV-based component score (0-100).
    pub hrv_component: f64,
    /// Resting heart rate component score (0-100).
    pub rhr_component: f64,
    /// Training load (TSB) component score (0-100).
    pub load_component: f64,
    /// Human-readable training recommendation.
    pub recommendation: String,
}

/// Compute a readiness score from HRV readings, resting HR readings, and training stress balance.
///
/// The score combines three components with different weights:
/// - HRV (40%): compares today's RMSSD to a 7-day rolling average
/// - Resting HR (30%): compares today's RHR to a 7-day baseline
/// - Training load (30%): maps TSB to a fatigue/freshness score
///
/// Returns a default mid-range score when insufficient data is available.
pub fn compute_readiness(
    hrv_readings: &[HrvReading],
    rhr_readings: &[RestingHrReading],
    tsb: Option<f64>,
) -> ReadinessScore {
    let hrv_component = compute_hrv_component(hrv_readings);
    let rhr_component = compute_rhr_component(rhr_readings);
    let load_component = compute_load_component(tsb);

    let weighted =
        hrv_component * HRV_WEIGHT + rhr_component * RHR_WEIGHT + load_component * LOAD_WEIGHT;
    let score = (weighted.round() as u8).min(100);
    let level = level_from_score(score);
    let recommendation = recommendation_for_level(level);

    ReadinessScore {
        score,
        level,
        hrv_component,
        rhr_component,
        load_component,
        recommendation,
    }
}

/// Compute the average RMSSD over the last `days` days from the given readings.
///
/// Filters readings to only include those within the lookback window ending at
/// the most recent reading's timestamp. Returns `None` if no readings fall
/// within the window.
pub fn compute_hrv_baseline(readings: &[HrvReading], days: u32) -> Option<f64> {
    if readings.is_empty() {
        return None;
    }
    let latest = readings.iter().map(|r| r.timestamp).max()?;
    let cutoff = latest - Duration::days(i64::from(days));

    let (sum, count) = readings
        .iter()
        .filter(|r| r.timestamp > cutoff)
        .fold((0.0, 0u32), |(s, c), r| (s + r.rmssd, c + 1));

    if count == 0 {
        None
    } else {
        Some(sum / f64::from(count))
    }
}

/// Compute the average resting heart rate over the last `days` days.
///
/// Filters readings to only include those within the lookback window ending at
/// the most recent reading's timestamp. Returns `None` if no readings fall
/// within the window.
pub fn compute_rhr_baseline(readings: &[RestingHrReading], days: u32) -> Option<f64> {
    if readings.is_empty() {
        return None;
    }
    let latest = readings.iter().map(|r| r.timestamp).max()?;
    let cutoff = latest - Duration::days(i64::from(days));

    let (sum, count) = readings
        .iter()
        .filter(|r| r.timestamp > cutoff)
        .fold((0.0, 0u32), |(s, c), r| (s + f64::from(r.bpm), c + 1));

    if count == 0 {
        None
    } else {
        Some(sum / f64::from(count))
    }
}

/// Compute the HRV component score (0-100).
///
/// Compares the most recent RMSSD reading to a 7-day baseline computed from
/// all readings *except* the most recent one. This prevents today's reading
/// from contaminating the baseline.
/// Formula: `(today / baseline) * 50`, clamped to 0-100.
fn compute_hrv_component(readings: &[HrvReading]) -> f64 {
    if readings.is_empty() {
        return 50.0;
    }
    let latest_ts = readings.iter().map(|r| r.timestamp).max().unwrap();
    let today = readings
        .iter()
        .find(|r| r.timestamp == latest_ts)
        .unwrap()
        .rmssd;

    let historical: Vec<HrvReading> = readings
        .iter()
        .filter(|r| r.timestamp != latest_ts)
        .cloned()
        .collect();

    let baseline = match compute_hrv_baseline(&historical, 7) {
        Some(b) if b > 0.0 => b,
        _ => return 50.0, // insufficient historical data
    };

    ((today / baseline) * 50.0).clamp(0.0, 100.0)
}

/// Compute the resting HR component score (0-100).
///
/// Compares the most recent RHR to a 7-day baseline computed from all readings
/// *except* the most recent one. This prevents today's reading from
/// contaminating the baseline.
/// Formula: `(1 - (today - baseline) / baseline) * 50 + 50`, clamped to 0-100.
fn compute_rhr_component(readings: &[RestingHrReading]) -> f64 {
    if readings.is_empty() {
        return 50.0;
    }
    let latest_ts = readings.iter().map(|r| r.timestamp).max().unwrap();
    let today = f64::from(
        readings
            .iter()
            .find(|r| r.timestamp == latest_ts)
            .unwrap()
            .bpm,
    );

    let historical: Vec<RestingHrReading> = readings
        .iter()
        .filter(|r| r.timestamp != latest_ts)
        .cloned()
        .collect();

    let baseline = match compute_rhr_baseline(&historical, 7) {
        Some(b) if b > 0.0 => b,
        _ => return 50.0,
    };

    let score = (1.0 - (today - baseline) / baseline) * 50.0 + 50.0;
    score.clamp(0.0, 100.0)
}

/// Compute the training load component score (0-100) from TSB.
///
/// Maps Training Stress Balance to readiness:
/// - TSB > 30 maps to 100 (very fresh)
/// - TSB = 0 maps to 50 (neutral)
/// - TSB < -30 maps to 0 (very fatigued)
///
/// Formula: `clamp((tsb + 30) * (100/60), 0, 100)`.
fn compute_load_component(tsb: Option<f64>) -> f64 {
    match tsb {
        Some(tsb_val) => ((tsb_val + 30.0) * (100.0 / 60.0)).clamp(0.0, 100.0),
        None => 50.0,
    }
}

/// Map a numeric score to a readiness level.
fn level_from_score(score: u8) -> ReadinessLevel {
    if score >= 70 {
        ReadinessLevel::Ready
    } else if score >= 40 {
        ReadinessLevel::Moderate
    } else {
        ReadinessLevel::Rest
    }
}

/// Generate a recommendation string for a given readiness level.
fn recommendation_for_level(level: ReadinessLevel) -> String {
    match level {
        ReadinessLevel::Ready => {
            "You are well-recovered. Great day for a hard workout or race.".to_string()
        }
        ReadinessLevel::Moderate => {
            "Moderate recovery detected. Consider a lighter session or technique work.".to_string()
        }
        ReadinessLevel::Rest => {
            "Your body needs rest. Prioritize sleep, nutrition, and easy movement.".to_string()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeZone;

    /// Create an HRV reading at a given day offset from a base date.
    fn hrv_at(day_offset: i64, rmssd: f64) -> HrvReading {
        let ts = Utc.with_ymd_and_hms(2026, 3, 10, 7, 0, 0).unwrap() + Duration::days(day_offset);
        HrvReading {
            timestamp: ts,
            rmssd,
        }
    }

    /// Create a resting HR reading at a given day offset from a base date.
    fn rhr_at(day_offset: i64, bpm: u16) -> RestingHrReading {
        let ts = Utc.with_ymd_and_hms(2026, 3, 10, 7, 0, 0).unwrap() + Duration::days(day_offset);
        RestingHrReading { timestamp: ts, bpm }
    }

    // ---- HRV baseline tests ----

    #[test]
    fn hrv_baseline_empty_returns_none() {
        assert_eq!(compute_hrv_baseline(&[], 7), None);
    }

    #[test]
    fn hrv_baseline_single_reading() {
        let readings = [hrv_at(0, 45.0)];
        let baseline = compute_hrv_baseline(&readings, 7).unwrap();
        assert!((baseline - 45.0).abs() < f64::EPSILON);
    }

    #[test]
    fn hrv_baseline_filters_old_readings() {
        let readings = [
            hrv_at(-10, 100.0), // outside 7-day window
            hrv_at(-3, 40.0),
            hrv_at(-1, 50.0),
            hrv_at(0, 60.0),
        ];
        let baseline = compute_hrv_baseline(&readings, 7).unwrap();
        assert!((baseline - 50.0).abs() < f64::EPSILON); // (40+50+60)/3
    }

    #[test]
    fn hrv_baseline_all_within_window() {
        let readings = [hrv_at(-2, 30.0), hrv_at(-1, 40.0), hrv_at(0, 50.0)];
        let baseline = compute_hrv_baseline(&readings, 7).unwrap();
        assert!((baseline - 40.0).abs() < f64::EPSILON);
    }

    // ---- RHR baseline tests ----

    #[test]
    fn rhr_baseline_empty_returns_none() {
        assert_eq!(compute_rhr_baseline(&[], 7), None);
    }

    #[test]
    fn rhr_baseline_single_reading() {
        let readings = [rhr_at(0, 60)];
        let baseline = compute_rhr_baseline(&readings, 7).unwrap();
        assert!((baseline - 60.0).abs() < f64::EPSILON);
    }

    #[test]
    fn rhr_baseline_filters_old_readings() {
        let readings = [
            rhr_at(-10, 80), // outside window
            rhr_at(-3, 58),
            rhr_at(-1, 60),
            rhr_at(0, 62),
        ];
        let baseline = compute_rhr_baseline(&readings, 7).unwrap();
        assert!((baseline - 60.0).abs() < f64::EPSILON); // (58+60+62)/3
    }

    // ---- Component score tests ----

    #[test]
    fn hrv_component_defaults_when_empty() {
        let score = compute_hrv_component(&[]);
        assert!((score - 50.0).abs() < f64::EPSILON);
    }

    #[test]
    fn hrv_component_above_baseline() {
        // 7 days of readings at 40.0, today at 60.0
        let mut readings: Vec<HrvReading> = (0..7).map(|d| hrv_at(-6 + d, 40.0)).collect();
        readings.push(hrv_at(1, 60.0));

        let component = compute_hrv_component(&readings);
        // today(60) / baseline(~40-ish including today) * 50
        // baseline includes all 8 readings within 7 days
        assert!(component > 50.0);
        assert!(component <= 100.0);
    }

    #[test]
    fn hrv_component_below_baseline() {
        let mut readings: Vec<HrvReading> = (0..7).map(|d| hrv_at(-6 + d, 60.0)).collect();
        readings.push(hrv_at(1, 30.0));

        let component = compute_hrv_component(&readings);
        assert!(component < 50.0);
    }

    #[test]
    fn hrv_component_clamped_to_100() {
        // Today's RMSSD far above baseline
        let mut readings: Vec<HrvReading> = (0..7).map(|d| hrv_at(-6 + d, 20.0)).collect();
        readings.push(hrv_at(1, 200.0));

        let component = compute_hrv_component(&readings);
        assert!((component - 100.0).abs() < f64::EPSILON);
    }

    #[test]
    fn rhr_component_defaults_when_empty() {
        let score = compute_rhr_component(&[]);
        assert!((score - 50.0).abs() < f64::EPSILON);
    }

    #[test]
    fn rhr_component_lower_than_baseline_is_good() {
        // Baseline: 65 bpm (historical). Today: 58 bpm (lower = good recovery).
        // score = (1 - (58 - 65)/65) * 50 + 50 = (1 + 0.1077) * 50 + 50 = 105.38
        // Clamped to 100.
        let mut readings: Vec<RestingHrReading> = (0..7).map(|d| rhr_at(-6 + d, 65)).collect();
        readings.push(rhr_at(1, 58));

        let component = compute_rhr_component(&readings);
        assert!((component - 100.0).abs() < f64::EPSILON);
    }

    #[test]
    fn rhr_component_higher_than_baseline_is_bad() {
        // Baseline: 7 days at 55 bpm (historical, excludes today).
        // Today: 72 bpm (elevated RHR = worse recovery).
        let mut readings: Vec<RestingHrReading> = (0..7).map(|d| rhr_at(-6 + d, 55)).collect();
        readings.push(rhr_at(1, 72));

        let component = compute_rhr_component(&readings);
        // baseline = 55.0, today = 72
        // score = (1 - (72 - 55)/55) * 50 + 50 = 0.691 * 50 + 50 = 84.5
        // At-baseline would give 100.0, so elevated RHR yields a lower score.
        assert!(
            component < 100.0,
            "elevated RHR should score below at-baseline (100)"
        );
        assert!(
            component > 50.0,
            "moderate elevation should still be above 50"
        );
    }

    #[test]
    fn load_component_no_tsb_defaults_to_50() {
        let score = compute_load_component(None);
        assert!((score - 50.0).abs() < f64::EPSILON);
    }

    #[test]
    fn load_component_positive_tsb() {
        let score = compute_load_component(Some(10.0));
        // (10 + 30) * 100/60 = 66.67
        assert!((score - 200.0 / 3.0).abs() < 0.01);
    }

    #[test]
    fn load_component_negative_tsb() {
        let score = compute_load_component(Some(-20.0));
        // (-20 + 30) * 100/60 = 16.67
        assert!((score - 50.0 / 3.0).abs() < 0.01);
    }

    #[test]
    fn load_component_clamped_at_zero() {
        let score = compute_load_component(Some(-50.0));
        assert!((score - 0.0).abs() < f64::EPSILON);
    }

    #[test]
    fn load_component_clamped_at_100() {
        let score = compute_load_component(Some(40.0));
        assert!((score - 100.0).abs() < f64::EPSILON);
    }

    // ---- ReadinessLevel tests ----

    #[test]
    fn level_ready() {
        assert_eq!(level_from_score(70), ReadinessLevel::Ready);
        assert_eq!(level_from_score(100), ReadinessLevel::Ready);
        assert_eq!(level_from_score(85), ReadinessLevel::Ready);
    }

    #[test]
    fn level_moderate() {
        assert_eq!(level_from_score(40), ReadinessLevel::Moderate);
        assert_eq!(level_from_score(69), ReadinessLevel::Moderate);
        assert_eq!(level_from_score(55), ReadinessLevel::Moderate);
    }

    #[test]
    fn level_rest() {
        assert_eq!(level_from_score(0), ReadinessLevel::Rest);
        assert_eq!(level_from_score(39), ReadinessLevel::Rest);
        assert_eq!(level_from_score(20), ReadinessLevel::Rest);
    }

    // ---- Full readiness computation tests ----

    #[test]
    fn readiness_with_all_empty_inputs() {
        let result = compute_readiness(&[], &[], None);
        // All components default to 50.0
        assert_eq!(result.score, 50);
        assert_eq!(result.level, ReadinessLevel::Moderate);
        assert!((result.hrv_component - 50.0).abs() < f64::EPSILON);
        assert!((result.rhr_component - 50.0).abs() < f64::EPSILON);
        assert!((result.load_component - 50.0).abs() < f64::EPSILON);
    }

    #[test]
    fn readiness_well_recovered_athlete() {
        // HRV above baseline, RHR below baseline, positive TSB
        let mut hrv: Vec<HrvReading> = (0..7).map(|d| hrv_at(-6 + d, 40.0)).collect();
        hrv.push(hrv_at(1, 55.0));

        let mut rhr: Vec<RestingHrReading> = (0..7).map(|d| rhr_at(-6 + d, 62)).collect();
        rhr.push(rhr_at(1, 55));

        let result = compute_readiness(&hrv, &rhr, Some(15.0));
        assert!(
            result.score >= 60,
            "Expected high score, got {}",
            result.score
        );
        assert!(result.level == ReadinessLevel::Ready || result.level == ReadinessLevel::Moderate,);
    }

    #[test]
    fn readiness_fatigued_athlete() {
        // HRV below baseline, RHR above baseline, very negative TSB
        let mut hrv: Vec<HrvReading> = (0..7).map(|d| hrv_at(-6 + d, 50.0)).collect();
        hrv.push(hrv_at(1, 20.0));

        let mut rhr: Vec<RestingHrReading> = (0..7).map(|d| rhr_at(-6 + d, 55)).collect();
        rhr.push(rhr_at(1, 75));

        let result = compute_readiness(&hrv, &rhr, Some(-25.0));
        assert!(
            result.score < 40,
            "Expected low score, got {}",
            result.score
        );
        assert_eq!(result.level, ReadinessLevel::Rest);
    }

    #[test]
    fn readiness_score_never_exceeds_100() {
        // Extreme positive values
        let mut hrv: Vec<HrvReading> = (0..7).map(|d| hrv_at(-6 + d, 10.0)).collect();
        hrv.push(hrv_at(1, 200.0));

        let mut rhr: Vec<RestingHrReading> = (0..7).map(|d| rhr_at(-6 + d, 80)).collect();
        rhr.push(rhr_at(1, 40));

        let result = compute_readiness(&hrv, &rhr, Some(50.0));
        assert!(result.score <= 100);
    }

    #[test]
    fn readiness_only_hrv_data() {
        let hrv: Vec<HrvReading> = (0..8).map(|d| hrv_at(-7 + d, 45.0)).collect();
        let result = compute_readiness(&hrv, &[], None);
        // RHR and load default to 50; HRV at baseline gives 50
        assert_eq!(result.score, 50);
    }

    #[test]
    fn readiness_recommendation_matches_level() {
        let ready = recommendation_for_level(ReadinessLevel::Ready);
        assert!(ready.contains("hard workout"));

        let moderate = recommendation_for_level(ReadinessLevel::Moderate);
        assert!(moderate.contains("lighter"));

        let rest = recommendation_for_level(ReadinessLevel::Rest);
        assert!(rest.contains("rest"));
    }

    #[test]
    fn readiness_single_hrv_reading() {
        let readings = [hrv_at(0, 45.0)];
        let result = compute_readiness(&readings, &[], None);
        // Single reading: today == baseline, so (45/45)*50 = 50
        assert!((result.hrv_component - 50.0).abs() < f64::EPSILON);
    }

    #[test]
    fn readiness_single_rhr_reading() {
        let readings = [rhr_at(0, 60)];
        let result = compute_readiness(&[], &readings, None);
        // Single reading: no historical baseline after excluding today, defaults to 50.
        assert!((result.rhr_component - 50.0).abs() < f64::EPSILON);
    }

    #[test]
    fn readiness_tsb_boundary_values() {
        // TSB = -30 should give load_component = 0
        assert!((compute_load_component(Some(-30.0)) - 0.0).abs() < f64::EPSILON);
        // TSB = 30 should give load_component = 100
        assert!((compute_load_component(Some(30.0)) - 100.0).abs() < f64::EPSILON);
    }

    #[test]
    fn readiness_extreme_hrv_zero_rmssd() {
        let readings = [hrv_at(0, 0.0), hrv_at(1, 0.0)];
        // Baseline is 0, should fall through to default
        let component = compute_hrv_component(&readings);
        assert!((component - 50.0).abs() < f64::EPSILON);
    }

    #[test]
    fn readiness_extreme_rhr_zero_bpm() {
        let readings = [rhr_at(0, 0), rhr_at(1, 0)];
        // Baseline is 0, should fall through to default
        let component = compute_rhr_component(&readings);
        assert!((component - 50.0).abs() < f64::EPSILON);
    }

    #[test]
    fn hrv_baseline_custom_window() {
        let readings = [
            hrv_at(-20, 100.0),
            hrv_at(-5, 40.0),
            hrv_at(-2, 50.0),
            hrv_at(0, 60.0),
        ];
        // 14-day window should include the -5 reading too
        let baseline_14 = compute_hrv_baseline(&readings, 14).unwrap();
        assert!((baseline_14 - 50.0).abs() < f64::EPSILON); // (40+50+60)/3

        // 30-day window should include all
        let baseline_30 = compute_hrv_baseline(&readings, 30).unwrap();
        assert!((baseline_30 - 62.5).abs() < f64::EPSILON); // (100+40+50+60)/4
    }
}
