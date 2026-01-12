//! Export functionality for training session data.
//!
//! This module provides functions to export completed training sessions in various
//! formats (CSV, JSON, text summary) for sharing and analysis. All functions are
//! pure with no I/O dependencies.

use super::heart_rate::Zone;
use super::session_history::CompletedSession;
use super::training_plan::calculate_zone;

/// Export a completed session to CSV format.
///
/// Generates a CSV file with columns: timestamp, bpm, zone, phase.
/// Each row represents one heart rate sample with its calculated zone.
///
/// # Examples
///
/// ```
/// use heart_beat::domain::export::export_to_csv;
/// use heart_beat::domain::session_history::{CompletedSession, SessionStatus, SessionSummary, HrSample};
/// use chrono::Utc;
///
/// let session = CompletedSession {
///     id: "test".to_string(),
///     plan_name: "Test Plan".to_string(),
///     start_time: Utc::now(),
///     end_time: Utc::now(),
///     status: SessionStatus::Completed,
///     hr_samples: vec![],
///     phases_completed: 1,
///     summary: SessionSummary {
///         duration_secs: 300,
///         avg_hr: 140,
///         max_hr: 160,
///         min_hr: 120,
///         time_in_zone: [0, 300, 0, 0, 0],
///     },
/// };
///
/// let csv = export_to_csv(&session);
/// assert!(csv.contains("timestamp,bpm,zone"));
/// ```
pub fn export_to_csv(session: &CompletedSession) -> String {
    let mut csv = String::from("timestamp,bpm,zone\n");

    let max_hr = if session.summary.max_hr > 0 {
        session.summary.max_hr
    } else {
        180 // Default fallback
    };

    for sample in &session.hr_samples {
        let zone = calculate_zone(sample.bpm, max_hr).ok().flatten();
        let zone_str = match zone {
            Some(Zone::Zone1) => "Zone1",
            Some(Zone::Zone2) => "Zone2",
            Some(Zone::Zone3) => "Zone3",
            Some(Zone::Zone4) => "Zone4",
            Some(Zone::Zone5) => "Zone5",
            None => "Unknown",
        };

        csv.push_str(&format!(
            "{},{},{}\n",
            sample.timestamp.to_rfc3339(),
            sample.bpm,
            zone_str
        ));
    }

    csv
}

/// Export a completed session to JSON format.
///
/// Uses serde_json to serialize the CompletedSession structure with
/// pretty printing for readability.
///
/// # Examples
///
/// ```
/// use heart_beat::domain::export::export_to_json;
/// use heart_beat::domain::session_history::{CompletedSession, SessionStatus, SessionSummary};
/// use chrono::Utc;
///
/// let session = CompletedSession {
///     id: "test".to_string(),
///     plan_name: "Test Plan".to_string(),
///     start_time: Utc::now(),
///     end_time: Utc::now(),
///     status: SessionStatus::Completed,
///     hr_samples: vec![],
///     phases_completed: 1,
///     summary: SessionSummary {
///         duration_secs: 300,
///         avg_hr: 140,
///         max_hr: 160,
///         min_hr: 120,
///         time_in_zone: [0, 300, 0, 0, 0],
///     },
/// };
///
/// let json = export_to_json(&session);
/// assert!(json.contains("\"plan_name\": \"Test Plan\""));
/// ```
pub fn export_to_json(session: &CompletedSession) -> String {
    serde_json::to_string_pretty(session).unwrap_or_else(|_| "{}".to_string())
}

/// Export a completed session to a human-readable text summary.
///
/// Generates a formatted text report with session metadata, heart rate
/// statistics, and time spent in each training zone.
///
/// # Examples
///
/// ```
/// use heart_beat::domain::export::export_to_summary;
/// use heart_beat::domain::session_history::{CompletedSession, SessionStatus, SessionSummary};
/// use chrono::Utc;
///
/// let session = CompletedSession {
///     id: "test".to_string(),
///     plan_name: "Test Plan".to_string(),
///     start_time: Utc::now(),
///     end_time: Utc::now(),
///     status: SessionStatus::Completed,
///     hr_samples: vec![],
///     phases_completed: 1,
///     summary: SessionSummary {
///         duration_secs: 300,
///         avg_hr: 140,
///         max_hr: 160,
///         min_hr: 120,
///         time_in_zone: [0, 300, 0, 0, 0],
///     },
/// };
///
/// let summary = export_to_summary(&session);
/// assert!(summary.contains("Heart Beat Training Session"));
/// assert!(summary.contains("Test Plan"));
/// ```
pub fn export_to_summary(session: &CompletedSession) -> String {
    let mut summary = String::new();

    // Header
    summary.push_str("Heart Beat Training Session\n");
    summary.push_str("===========================\n\n");

    // Session metadata
    summary.push_str(&format!("Plan: {}\n", session.plan_name));
    summary.push_str(&format!(
        "Date: {}\n",
        session.start_time.format("%B %d, %Y at %H:%M")
    ));
    summary.push_str(&format!(
        "Duration: {}:{:02}\n",
        session.summary.duration_secs / 60,
        session.summary.duration_secs % 60
    ));
    summary.push_str(&format!("Status: {:?}\n\n", session.status));

    // Heart rate summary
    summary.push_str("Heart Rate Summary\n");
    summary.push_str("------------------\n");
    summary.push_str(&format!("Average: {} BPM\n", session.summary.avg_hr));
    summary.push_str(&format!("Maximum: {} BPM\n", session.summary.max_hr));
    summary.push_str(&format!("Minimum: {} BPM\n\n", session.summary.min_hr));

    // Time in zones
    summary.push_str("Time in Zones\n");
    summary.push_str("-------------\n");

    let total_secs = session.summary.duration_secs;
    let zone_names = [
        "Zone 1 (Recovery)",
        "Zone 2 (Fat Burning)",
        "Zone 3 (Aerobic)",
        "Zone 4 (Threshold)",
        "Zone 5 (Maximum)",
    ];

    for (i, zone_time) in session.summary.time_in_zone.iter().enumerate() {
        let percentage = if total_secs > 0 {
            (*zone_time as f32 / total_secs as f32 * 100.0) as u32
        } else {
            0
        };

        summary.push_str(&format!(
            "{}: {}:{:02} ({}%)\n",
            zone_names[i],
            zone_time / 60,
            zone_time % 60,
            percentage
        ));
    }

    summary
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::session_history::{HrSample, SessionStatus, SessionSummary};
    use chrono::Utc;

    fn create_test_session() -> CompletedSession {
        let start = Utc::now();
        let end = start + chrono::Duration::seconds(300);

        CompletedSession {
            id: "test-123".to_string(),
            plan_name: "Tempo Run".to_string(),
            start_time: start,
            end_time: end,
            status: SessionStatus::Completed,
            hr_samples: vec![
                HrSample {
                    timestamp: start,
                    bpm: 120,
                },
                HrSample {
                    timestamp: start + chrono::Duration::seconds(60),
                    bpm: 140,
                },
                HrSample {
                    timestamp: start + chrono::Duration::seconds(120),
                    bpm: 160,
                },
            ],
            phases_completed: 3,
            summary: SessionSummary {
                duration_secs: 300,
                avg_hr: 140,
                max_hr: 160,
                min_hr: 120,
                time_in_zone: [0, 100, 150, 50, 0],
            },
        }
    }

    #[test]
    fn test_export_to_csv_format() {
        let session = create_test_session();
        let csv = export_to_csv(&session);

        // Check header
        assert!(csv.starts_with("timestamp,bpm,zone\n"));

        // Check that it contains sample data
        assert!(csv.contains("120,Zone"));
        assert!(csv.contains("140,Zone"));
        assert!(csv.contains("160,Zone"));

        // Check line count (header + 3 samples)
        assert_eq!(csv.lines().count(), 4);
    }

    #[test]
    fn test_export_to_csv_empty_samples() {
        let mut session = create_test_session();
        session.hr_samples = vec![];
        let csv = export_to_csv(&session);

        // Should only have header
        assert_eq!(csv, "timestamp,bpm,zone\n");
    }

    #[test]
    fn test_export_to_json_valid() {
        let session = create_test_session();
        let json = export_to_json(&session);

        // Verify it's valid JSON by parsing it back
        let parsed: serde_json::Value = serde_json::from_str(&json).expect("JSON should be valid");

        // Check key fields
        assert_eq!(parsed["plan_name"], "Tempo Run");
        assert_eq!(parsed["summary"]["avg_hr"], 140);
        assert_eq!(parsed["phases_completed"], 3);
    }

    #[test]
    fn test_export_to_summary_format() {
        let session = create_test_session();
        let summary = export_to_summary(&session);

        // Check header
        assert!(summary.contains("Heart Beat Training Session"));
        assert!(summary.contains("==========================="));

        // Check metadata
        assert!(summary.contains("Plan: Tempo Run"));
        assert!(summary.contains("Duration: 5:00"));

        // Check heart rate stats
        assert!(summary.contains("Heart Rate Summary"));
        assert!(summary.contains("Average: 140 BPM"));
        assert!(summary.contains("Maximum: 160 BPM"));
        assert!(summary.contains("Minimum: 120 BPM"));

        // Check zones
        assert!(summary.contains("Time in Zones"));
        assert!(summary.contains("Zone 1 (Recovery)"));
        assert!(summary.contains("Zone 2 (Fat Burning): 1:40"));
        assert!(summary.contains("Zone 3 (Aerobic): 2:30"));
        assert!(summary.contains("Zone 4 (Threshold): 0:50"));
    }

    #[test]
    fn test_export_to_summary_percentages() {
        let session = create_test_session();
        let summary = export_to_summary(&session);

        // Check percentage calculations (100s out of 300s total)
        assert!(summary.contains("(33%)")); // Zone 2: 100/300
        assert!(summary.contains("(50%)")); // Zone 3: 150/300
        assert!(summary.contains("(16%)")); // Zone 4: 50/300 (rounds to 16%)
    }

    #[test]
    fn test_export_to_summary_zero_duration() {
        let mut session = create_test_session();
        session.summary.duration_secs = 0;
        let summary = export_to_summary(&session);

        // Should handle division by zero gracefully
        assert!(summary.contains("(0%)"));
    }
}
