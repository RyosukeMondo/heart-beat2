//! Analytics domain logic for computing training trends and summaries.
//!
//! Pure computation functions that operate on completed session data to produce
//! aggregated metrics like weekly summaries, HR trends, and zone distributions.

use crate::domain::session_history::CompletedSession;
use chrono::{Datelike, NaiveDate};
use std::collections::BTreeMap;

/// Summary of training for a specific week.
#[derive(Debug, Clone, PartialEq)]
pub struct WeeklySummary {
    /// Monday of the week (as Unix millis).
    pub week_start_millis: i64,
    /// Number of sessions in this week.
    pub session_count: u32,
    /// Total training duration in seconds.
    pub total_duration_secs: u32,
    /// Average heart rate across all sessions.
    pub avg_hr: u16,
    /// Aggregated time in each zone (5 zones).
    pub time_in_zone: [u32; 5],
}

/// A single data point for trend charts.
#[derive(Debug, Clone, PartialEq)]
pub struct TrendPoint {
    /// Unix timestamp in milliseconds.
    pub timestamp_millis: i64,
    /// The metric value at this point.
    pub value: f64,
}

/// Compute weekly summaries from completed sessions.
///
/// Groups sessions by ISO week and aggregates metrics.
/// Returns summaries sorted chronologically.
pub fn compute_weekly_summaries(sessions: &[CompletedSession]) -> Vec<WeeklySummary> {
    if sessions.is_empty() {
        return Vec::new();
    }

    let mut weeks: BTreeMap<NaiveDate, WeekAccumulator> = BTreeMap::new();

    for session in sessions {
        let date = session.start_time.date_naive();
        let monday = week_start(date);
        let acc = weeks.entry(monday).or_insert_with(WeekAccumulator::new);
        acc.add(session);
    }

    weeks
        .into_iter()
        .map(|(monday, acc)| acc.into_summary(monday))
        .collect()
}

/// Compute average HR trend (one point per session, chronological).
pub fn compute_hr_trend(sessions: &[CompletedSession]) -> Vec<TrendPoint> {
    sessions
        .iter()
        .map(|s| TrendPoint {
            timestamp_millis: s.start_time.timestamp_millis(),
            value: s.summary.avg_hr as f64,
        })
        .collect()
}

/// Compute training volume trend (total minutes per week).
pub fn compute_volume_trend(sessions: &[CompletedSession]) -> Vec<TrendPoint> {
    if sessions.is_empty() {
        return Vec::new();
    }

    let mut weeks: BTreeMap<NaiveDate, u32> = BTreeMap::new();

    for session in sessions {
        let date = session.start_time.date_naive();
        let monday = week_start(date);
        *weeks.entry(monday).or_insert(0) += session.summary.duration_secs;
    }

    weeks
        .into_iter()
        .map(|(monday, secs)| TrendPoint {
            timestamp_millis: monday_to_millis(monday),
            value: secs as f64 / 60.0,
        })
        .collect()
}

/// Compute overall time-in-zone distribution across all sessions.
pub fn compute_zone_distribution(sessions: &[CompletedSession]) -> [u32; 5] {
    let mut total = [0u32; 5];
    for session in sessions {
        for (i, &secs) in session.summary.time_in_zone.iter().enumerate() {
            total[i] += secs;
        }
    }
    total
}

/// Compute training consistency (sessions per week over time).
pub fn compute_consistency_trend(sessions: &[CompletedSession]) -> Vec<TrendPoint> {
    if sessions.is_empty() {
        return Vec::new();
    }

    let mut weeks: BTreeMap<NaiveDate, u32> = BTreeMap::new();

    for session in sessions {
        let date = session.start_time.date_naive();
        let monday = week_start(date);
        *weeks.entry(monday).or_insert(0) += 1;
    }

    weeks
        .into_iter()
        .map(|(monday, count)| TrendPoint {
            timestamp_millis: monday_to_millis(monday),
            value: count as f64,
        })
        .collect()
}

/// Get the Monday of the week for a given date.
fn week_start(date: NaiveDate) -> NaiveDate {
    let days_since_monday = date.weekday().num_days_from_monday();
    date - chrono::Duration::days(days_since_monday as i64)
}

/// Convert a NaiveDate (Monday) to Unix millis at midnight UTC.
fn monday_to_millis(date: NaiveDate) -> i64 {
    date.and_hms_opt(0, 0, 0)
        .expect("valid time")
        .and_utc()
        .timestamp_millis()
}

/// Accumulator for aggregating session data within a week.
struct WeekAccumulator {
    count: u32,
    total_duration_secs: u32,
    total_hr_weighted: u64,
    time_in_zone: [u32; 5],
}

impl WeekAccumulator {
    fn new() -> Self {
        Self {
            count: 0,
            total_duration_secs: 0,
            total_hr_weighted: 0,
            time_in_zone: [0; 5],
        }
    }

    fn add(&mut self, session: &CompletedSession) {
        self.count += 1;
        self.total_duration_secs += session.summary.duration_secs;
        // Weight avg HR by session duration for proper averaging
        self.total_hr_weighted +=
            session.summary.avg_hr as u64 * session.summary.duration_secs as u64;
        for (i, &secs) in session.summary.time_in_zone.iter().enumerate() {
            self.time_in_zone[i] += secs;
        }
    }

    fn into_summary(self, monday: NaiveDate) -> WeeklySummary {
        let avg_hr = if self.total_duration_secs > 0 {
            (self.total_hr_weighted / self.total_duration_secs as u64) as u16
        } else {
            0
        };

        WeeklySummary {
            week_start_millis: monday_to_millis(monday),
            session_count: self.count,
            total_duration_secs: self.total_duration_secs,
            avg_hr,
            time_in_zone: self.time_in_zone,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::session_history::{SessionStatus, SessionSummary};
    use chrono::{TimeZone, Utc};

    fn make_session(id: &str, date_str: &str, duration: u32, avg_hr: u16) -> CompletedSession {
        let start = Utc.from_utc_datetime(
            &NaiveDate::parse_from_str(date_str, "%Y-%m-%d")
                .unwrap()
                .and_hms_opt(10, 0, 0)
                .unwrap(),
        );
        let end = start + chrono::Duration::seconds(duration as i64);

        CompletedSession {
            id: id.to_string(),
            plan_name: "Test".to_string(),
            start_time: start,
            end_time: end,
            status: SessionStatus::Completed,
            hr_samples: vec![],
            phases_completed: 1,
            summary: SessionSummary {
                duration_secs: duration,
                avg_hr,
                max_hr: avg_hr + 20,
                min_hr: avg_hr.saturating_sub(20),
                time_in_zone: [60, 120, 180, 60, 0],
            },
        }
    }

    #[test]
    fn test_empty_sessions() {
        assert!(compute_weekly_summaries(&[]).is_empty());
        assert!(compute_hr_trend(&[]).is_empty());
        assert!(compute_volume_trend(&[]).is_empty());
        assert_eq!(compute_zone_distribution(&[]), [0; 5]);
        assert!(compute_consistency_trend(&[]).is_empty());
    }

    #[test]
    fn test_weekly_summary_single_session() {
        let sessions = vec![make_session("s1", "2026-03-16", 1800, 140)];
        let summaries = compute_weekly_summaries(&sessions);

        assert_eq!(summaries.len(), 1);
        assert_eq!(summaries[0].session_count, 1);
        assert_eq!(summaries[0].total_duration_secs, 1800);
        assert_eq!(summaries[0].avg_hr, 140);
    }

    #[test]
    fn test_weekly_summary_multiple_weeks() {
        let sessions = vec![
            make_session("s1", "2026-03-16", 1800, 140), // Week of Mar 16
            make_session("s2", "2026-03-17", 1200, 130), // Same week
            make_session("s3", "2026-03-23", 2400, 150), // Next week
        ];
        let summaries = compute_weekly_summaries(&sessions);

        assert_eq!(summaries.len(), 2);
        assert_eq!(summaries[0].session_count, 2);
        assert_eq!(summaries[0].total_duration_secs, 3000);
        assert_eq!(summaries[1].session_count, 1);
    }

    #[test]
    fn test_hr_trend() {
        let sessions = vec![
            make_session("s1", "2026-03-16", 1800, 140),
            make_session("s2", "2026-03-17", 1200, 150),
        ];
        let trend = compute_hr_trend(&sessions);

        assert_eq!(trend.len(), 2);
        assert_eq!(trend[0].value, 140.0);
        assert_eq!(trend[1].value, 150.0);
    }

    #[test]
    fn test_volume_trend() {
        let sessions = vec![
            make_session("s1", "2026-03-16", 1800, 140),
            make_session("s2", "2026-03-17", 1200, 130),
        ];
        let trend = compute_volume_trend(&sessions);

        assert_eq!(trend.len(), 1); // Same week
        assert_eq!(trend[0].value, 50.0); // (1800 + 1200) / 60
    }

    #[test]
    fn test_zone_distribution() {
        let sessions = vec![
            make_session("s1", "2026-03-16", 1800, 140),
            make_session("s2", "2026-03-17", 1200, 130),
        ];
        let dist = compute_zone_distribution(&sessions);

        assert_eq!(dist, [120, 240, 360, 120, 0]);
    }

    #[test]
    fn test_consistency_trend() {
        let sessions = vec![
            make_session("s1", "2026-03-16", 1800, 140),
            make_session("s2", "2026-03-17", 1200, 130),
            make_session("s3", "2026-03-23", 2400, 150),
        ];
        let trend = compute_consistency_trend(&sessions);

        assert_eq!(trend.len(), 2);
        assert_eq!(trend[0].value, 2.0); // 2 sessions in first week
        assert_eq!(trend[1].value, 1.0); // 1 session in second week
    }

    #[test]
    fn test_week_start_monday() {
        // 2026-03-20 is a Friday
        let friday = NaiveDate::from_ymd_opt(2026, 3, 20).unwrap();
        let monday = week_start(friday);
        assert_eq!(monday, NaiveDate::from_ymd_opt(2026, 3, 16).unwrap());
        assert_eq!(monday.weekday(), chrono::Weekday::Mon);
    }

    #[test]
    fn test_week_start_already_monday() {
        let monday = NaiveDate::from_ymd_opt(2026, 3, 16).unwrap();
        assert_eq!(week_start(monday), monday);
    }
}
