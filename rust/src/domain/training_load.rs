//! Training load domain logic for computing TRIMP, CTL, ATL, and TSB.
//!
//! Pure computation functions that operate on completed session data to produce
//! training load metrics using Edwards TRIMP and exponential moving averages.
//! These metrics help athletes monitor fitness, fatigue, and form over time.

use crate::domain::session_history::CompletedSession;
use chrono::NaiveDate;
use std::collections::BTreeMap;

/// Edwards TRIMP zone weighting factors (Zone1 through Zone5).
const ZONE_FACTORS: [f64; 5] = [1.0, 2.0, 3.0, 4.0, 5.0];

/// Number of days for Chronic Training Load (fitness) EMA.
const CTL_DAYS: f64 = 42.0;

/// Number of days for Acute Training Load (fatigue) EMA.
const ATL_DAYS: f64 = 7.0;

/// Aggregated TRIMP score for a single calendar day.
#[derive(Debug, Clone, PartialEq)]
pub struct DailyTrimp {
    /// The calendar date (UTC).
    pub date: NaiveDate,
    /// Total TRIMP score for all sessions on this date.
    pub trimp: f64,
}

/// Training load metrics at a specific point in time.
///
/// CTL (Chronic Training Load) represents long-term fitness built over ~42 days.
/// ATL (Acute Training Load) represents short-term fatigue over ~7 days.
/// TSB (Training Stress Balance) = CTL - ATL, representing current form.
/// Positive TSB suggests freshness; negative TSB suggests accumulated fatigue.
#[derive(Debug, Clone, PartialEq)]
pub struct TrainingLoadMetrics {
    /// Chronic Training Load (fitness) - 42-day exponential moving average.
    pub ctl: f64,
    /// Acute Training Load (fatigue) - 7-day exponential moving average.
    pub atl: f64,
    /// Training Stress Balance (form) = CTL - ATL.
    pub tsb: f64,
    /// The date these metrics correspond to.
    pub date: NaiveDate,
}

/// Compute Edwards TRIMP score for a single completed session.
///
/// Edwards TRIMP weights time spent in each heart rate zone by a zone factor:
/// Zone 1 = 1x, Zone 2 = 2x, Zone 3 = 3x, Zone 4 = 4x, Zone 5 = 5x.
/// Time is converted from seconds to minutes before weighting.
pub fn compute_session_trimp(session: &CompletedSession) -> f64 {
    session
        .summary
        .time_in_zone
        .iter()
        .zip(ZONE_FACTORS.iter())
        .map(|(&secs, &factor)| (secs as f64 / 60.0) * factor)
        .sum()
}

/// Aggregate TRIMP scores per calendar day from completed sessions.
///
/// Groups sessions by their start date (UTC) and sums TRIMP values.
/// Returns results sorted chronologically.
pub fn compute_daily_trimp(sessions: &[CompletedSession]) -> Vec<DailyTrimp> {
    if sessions.is_empty() {
        return Vec::new();
    }

    let mut by_date: BTreeMap<NaiveDate, f64> = BTreeMap::new();
    for session in sessions {
        let date = session.start_time.date_naive();
        let trimp = compute_session_trimp(session);
        *by_date.entry(date).or_insert(0.0) += trimp;
    }

    by_date
        .into_iter()
        .map(|(date, trimp)| DailyTrimp { date, trimp })
        .collect()
}

/// Compute training load metrics (CTL/ATL/TSB) over time using EMAs.
///
/// Fills gaps between training days with zero TRIMP to ensure continuous
/// daily metrics. Uses exponential moving averages with standard constants:
/// CTL uses a 42-day window, ATL uses a 7-day window.
///
/// Returns one `TrainingLoadMetrics` per day from the first to last session date.
pub fn compute_training_load(daily_trimp: &[DailyTrimp]) -> Vec<TrainingLoadMetrics> {
    if daily_trimp.is_empty() {
        return Vec::new();
    }

    let trimp_map: BTreeMap<NaiveDate, f64> =
        daily_trimp.iter().map(|dt| (dt.date, dt.trimp)).collect();

    let first_date = daily_trimp.iter().map(|dt| dt.date).min().unwrap();
    let last_date = daily_trimp.iter().map(|dt| dt.date).max().unwrap();
    let ctl_alpha = 2.0 / (CTL_DAYS + 1.0);
    let atl_alpha = 2.0 / (ATL_DAYS + 1.0);

    let mut ctl = 0.0_f64;
    let mut atl = 0.0_f64;
    let mut results = Vec::new();
    let mut current = first_date;

    while current <= last_date {
        let trimp = trimp_map.get(&current).copied().unwrap_or(0.0);
        ctl += ctl_alpha * (trimp - ctl);
        atl += atl_alpha * (trimp - atl);
        results.push(TrainingLoadMetrics {
            ctl,
            atl,
            tsb: ctl - atl,
            date: current,
        });
        current = next_day(current);
    }

    results
}

/// Get the latest training load metrics from daily TRIMP data.
///
/// Returns `None` if the input is empty.
pub fn current_training_load(daily_trimp: &[DailyTrimp]) -> Option<TrainingLoadMetrics> {
    compute_training_load(daily_trimp).into_iter().last()
}

/// Advance a `NaiveDate` by one day.
fn next_day(date: NaiveDate) -> NaiveDate {
    date.succ_opt().expect("date within valid range")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::session_history::{SessionStatus, SessionSummary};
    use chrono::{TimeZone, Utc};

    fn date(y: i32, m: u32, d: u32) -> NaiveDate {
        NaiveDate::from_ymd_opt(y, m, d).unwrap()
    }

    fn add_days(base: NaiveDate, n: u64) -> NaiveDate {
        base.checked_add_days(chrono::Days::new(n)).unwrap()
    }

    fn dt(date: NaiveDate, trimp: f64) -> DailyTrimp {
        DailyTrimp { date, trimp }
    }

    fn make_session(
        id: &str,
        date_str: &str,
        duration: u32,
        avg_hr: u16,
        tiz: [u32; 5],
    ) -> CompletedSession {
        let start = Utc.from_utc_datetime(
            &NaiveDate::parse_from_str(date_str, "%Y-%m-%d")
                .unwrap()
                .and_hms_opt(10, 0, 0)
                .unwrap(),
        );
        CompletedSession {
            id: id.to_string(),
            plan_name: "Test".to_string(),
            start_time: start,
            end_time: start + chrono::Duration::seconds(duration as i64),
            status: SessionStatus::Completed,
            hr_samples: vec![],
            phases_completed: 1,
            summary: SessionSummary {
                duration_secs: duration,
                avg_hr,
                max_hr: avg_hr + 20,
                min_hr: avg_hr.saturating_sub(20),
                time_in_zone: tiz,
            },
        }
    }

    fn make_default_session(id: &str, date_str: &str) -> CompletedSession {
        make_session(id, date_str, 420, 140, [60, 120, 180, 60, 0])
    }

    // --- compute_session_trimp ---

    #[test]
    fn trimp_empty_zones_returns_zero() {
        let s = make_session("s1", "2026-03-01", 0, 0, [0, 0, 0, 0, 0]);
        assert_eq!(compute_session_trimp(&s), 0.0);
    }

    #[test]
    fn trimp_single_zone() {
        let s = make_session("s1", "2026-03-01", 120, 140, [0, 0, 120, 0, 0]);
        assert!((compute_session_trimp(&s) - 6.0).abs() < f64::EPSILON);
    }

    #[test]
    fn trimp_all_zones() {
        // Z1:1*1 + Z2:2*2 + Z3:3*3 + Z4:4*4 + Z5:5*5 = 1+4+9+16+25 = 55
        let s = make_session("s1", "2026-03-01", 900, 150, [60, 120, 180, 240, 300]);
        assert!((compute_session_trimp(&s) - 55.0).abs() < f64::EPSILON);
    }

    #[test]
    fn trimp_only_zone5() {
        let s = make_session("s1", "2026-03-01", 300, 180, [0, 0, 0, 0, 300]);
        assert!((compute_session_trimp(&s) - 25.0).abs() < f64::EPSILON);
    }

    // --- compute_daily_trimp ---

    #[test]
    fn daily_trimp_empty_sessions() {
        assert!(compute_daily_trimp(&[]).is_empty());
    }

    #[test]
    fn daily_trimp_single_session() {
        let daily = compute_daily_trimp(&[make_default_session("s1", "2026-03-01")]);
        assert_eq!(daily.len(), 1);
        assert_eq!(daily[0].date, date(2026, 3, 1));
        // Z1:1*1 + Z2:2*2 + Z3:3*3 + Z4:1*4 = 1+4+9+4 = 18.0
        assert!((daily[0].trimp - 18.0).abs() < f64::EPSILON);
    }

    #[test]
    fn daily_trimp_multiple_sessions_same_day() {
        let sessions = vec![
            make_default_session("s1", "2026-03-01"),
            make_default_session("s2", "2026-03-01"),
        ];
        let daily = compute_daily_trimp(&sessions);
        assert_eq!(daily.len(), 1);
        assert!((daily[0].trimp - 36.0).abs() < f64::EPSILON);
    }

    #[test]
    fn daily_trimp_multiple_days_sorted() {
        let sessions = vec![
            make_default_session("s2", "2026-03-05"),
            make_default_session("s1", "2026-03-01"),
            make_default_session("s3", "2026-03-03"),
        ];
        let daily = compute_daily_trimp(&sessions);
        assert_eq!(daily.len(), 3);
        assert_eq!(daily[0].date, date(2026, 3, 1));
        assert_eq!(daily[1].date, date(2026, 3, 3));
        assert_eq!(daily[2].date, date(2026, 3, 5));
    }

    // --- compute_training_load ---

    #[test]
    fn training_load_empty_input() {
        assert!(compute_training_load(&[]).is_empty());
    }

    #[test]
    fn training_load_single_day() {
        let metrics = compute_training_load(&[dt(date(2026, 3, 1), 50.0)]);
        assert_eq!(metrics.len(), 1);
        assert_eq!(metrics[0].date, date(2026, 3, 1));
        let expected_ctl = 2.0 / 43.0 * 50.0;
        let expected_atl = 2.0 / 8.0 * 50.0;
        assert!((metrics[0].ctl - expected_ctl).abs() < 1e-10);
        assert!((metrics[0].atl - expected_atl).abs() < 1e-10);
        assert!((metrics[0].tsb - (expected_ctl - expected_atl)).abs() < 1e-10);
    }

    #[test]
    fn training_load_fills_gaps_with_zero_trimp() {
        let daily = vec![dt(date(2026, 3, 1), 50.0), dt(date(2026, 3, 4), 60.0)];
        let metrics = compute_training_load(&daily);
        assert_eq!(metrics.len(), 4);
        assert_eq!(metrics[0].date, date(2026, 3, 1));
        assert_eq!(metrics[1].date, date(2026, 3, 2));
        assert_eq!(metrics[2].date, date(2026, 3, 3));
        assert_eq!(metrics[3].date, date(2026, 3, 4));
        // Gap days should have decaying values
        assert!(metrics[1].ctl < metrics[0].ctl);
        assert!(metrics[1].atl < metrics[0].atl);
    }

    #[test]
    fn training_load_ema_convergence_constant_load() {
        let base = date(2026, 1, 1);
        let daily: Vec<DailyTrimp> = (0..100).map(|i| dt(add_days(base, i), 40.0)).collect();
        let last = compute_training_load(&daily).into_iter().last().unwrap();
        assert!((last.ctl - 40.0).abs() < 1.0);
        assert!((last.atl - 40.0).abs() < 0.1);
        assert!(last.tsb.abs() < 1.0);
    }

    #[test]
    fn training_load_atl_responds_faster_than_ctl() {
        let base = date(2026, 1, 1);
        let mut daily: Vec<DailyTrimp> = (0..20).map(|i| dt(add_days(base, i), 20.0)).collect();
        daily.push(dt(add_days(base, 20), 100.0));
        let metrics = compute_training_load(&daily);
        let atl_jump = metrics[20].atl - metrics[19].atl;
        let ctl_jump = metrics[20].ctl - metrics[19].ctl;
        assert!(atl_jump > ctl_jump);
        assert!(atl_jump > 0.0);
        assert!(ctl_jump > 0.0);
    }

    #[test]
    fn training_load_tsb_negative_after_hard_block() {
        let base = date(2026, 1, 1);
        let daily: Vec<DailyTrimp> = (0..7).map(|i| dt(add_days(base, i), 80.0)).collect();
        let last = compute_training_load(&daily).into_iter().last().unwrap();
        assert!(last.tsb < 0.0, "TSB should be negative: {}", last.tsb);
    }

    #[test]
    fn training_load_tsb_positive_after_rest() {
        let base = date(2026, 1, 1);
        let daily: Vec<DailyTrimp> = (0..28)
            .map(|i| dt(add_days(base, i), if i < 14 { 60.0 } else { 0.0 }))
            .collect();
        let last = compute_training_load(&daily).into_iter().last().unwrap();
        assert!(
            last.tsb > 0.0,
            "TSB should be positive after rest: {}",
            last.tsb
        );
    }

    // --- current_training_load ---

    #[test]
    fn current_training_load_empty() {
        assert!(current_training_load(&[]).is_none());
    }

    #[test]
    fn current_training_load_returns_last_day() {
        let daily = vec![dt(date(2026, 3, 1), 50.0), dt(date(2026, 3, 3), 60.0)];
        let current = current_training_load(&daily).unwrap();
        assert_eq!(current.date, date(2026, 3, 3));
    }

    #[test]
    fn current_matches_last_of_full_series() {
        let daily = vec![dt(date(2026, 3, 1), 40.0), dt(date(2026, 3, 5), 55.0)];
        let full = compute_training_load(&daily);
        let current = current_training_load(&daily).unwrap();
        assert_eq!(current, *full.last().unwrap());
    }

    // --- Integration ---

    #[test]
    fn end_to_end_sessions_to_training_load() {
        let sessions = vec![
            make_session("s1", "2026-03-01", 900, 150, [60, 120, 180, 240, 300]),
            make_session("s2", "2026-03-01", 600, 130, [120, 120, 120, 120, 120]),
            make_session("s3", "2026-03-03", 1200, 145, [0, 0, 600, 600, 0]),
        ];
        let daily = compute_daily_trimp(&sessions);
        assert_eq!(daily.len(), 2);
        let metrics = compute_training_load(&daily);
        assert_eq!(metrics.len(), 3);
        for m in &metrics {
            assert!(!m.ctl.is_nan() && !m.atl.is_nan() && !m.tsb.is_nan());
            assert_eq!(m.tsb, m.ctl - m.atl);
        }
    }

    #[test]
    fn tsb_always_equals_ctl_minus_atl() {
        let base = date(2026, 1, 1);
        let daily: Vec<DailyTrimp> = (0..30)
            .map(|i| dt(add_days(base, i), if i % 3 == 0 { 50.0 } else { 0.0 }))
            .collect();
        for m in &compute_training_load(&daily) {
            assert!(
                (m.tsb - (m.ctl - m.atl)).abs() < 1e-10,
                "TSB invariant violated on {}: tsb={}, ctl-atl={}",
                m.date,
                m.tsb,
                m.ctl - m.atl
            );
        }
    }
}
