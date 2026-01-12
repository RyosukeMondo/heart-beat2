//! Session history domain types for storing completed training sessions.
//!
//! This module provides types for persisting training session data, including
//! heart rate samples, phase completion, and summary statistics. All types are
//! pure data structures with no I/O dependencies.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// A completed training session with full history and statistics.
///
/// Represents a training session that has been executed, whether it completed
/// normally, was interrupted, or stopped early. Includes all heart rate
/// samples collected during the session and summary statistics.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CompletedSession {
    /// Unique identifier for this session.
    pub id: String,

    /// Name of the training plan that was executed.
    pub plan_name: String,

    /// When the session started.
    pub start_time: DateTime<Utc>,

    /// When the session ended.
    pub end_time: DateTime<Utc>,

    /// Final status of the session.
    pub status: SessionStatus,

    /// All heart rate samples collected during the session.
    pub hr_samples: Vec<HrSample>,

    /// Number of phases that were completed.
    pub phases_completed: u32,

    /// Statistical summary of the session.
    pub summary: SessionSummary,
}

/// Status of a completed session.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SessionStatus {
    /// Session completed all phases successfully.
    Completed,

    /// Session was interrupted (e.g., connection lost, app crashed).
    Interrupted,

    /// Session was manually stopped by the user.
    Stopped,
}

/// Summary statistics for a training session.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SessionSummary {
    /// Total duration of the session in seconds.
    pub duration_secs: u32,

    /// Average heart rate during the session.
    pub avg_hr: u16,

    /// Maximum heart rate reached during the session.
    pub max_hr: u16,

    /// Minimum heart rate recorded during the session.
    pub min_hr: u16,

    /// Time spent in each heart rate zone in seconds.
    ///
    /// Indexed by zone number (0-4 for Zone1-Zone5).
    pub time_in_zone: [u32; 5],
}

/// A single heart rate sample at a specific point in time.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct HrSample {
    /// Timestamp when this sample was recorded.
    pub timestamp: DateTime<Utc>,

    /// Heart rate in beats per minute.
    pub bpm: u16,
}

/// Result of completing a single training phase.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PhaseResult {
    /// Name of the completed phase.
    pub phase_name: String,

    /// When the phase started.
    pub start_time: DateTime<Utc>,

    /// When the phase ended.
    pub end_time: DateTime<Utc>,

    /// Average heart rate during this phase.
    pub avg_hr: u16,

    /// Maximum heart rate during this phase.
    pub max_hr: u16,

    /// Minimum heart rate during this phase.
    pub min_hr: u16,
}

impl CompletedSession {
    /// Calculate the duration of the session in seconds.
    pub fn duration_secs(&self) -> i64 {
        self.end_time
            .signed_duration_since(self.start_time)
            .num_seconds()
    }

    /// Check if the session completed successfully.
    pub fn is_completed(&self) -> bool {
        self.status == SessionStatus::Completed
    }
}

impl SessionSummary {
    /// Create a summary from a list of heart rate samples.
    ///
    /// Calculates average, min, max heart rates from the samples.
    /// The caller should provide time_in_zone separately as it requires
    /// zone calculation based on max_hr.
    pub fn from_samples(samples: &[HrSample], duration_secs: u32, time_in_zone: [u32; 5]) -> Self {
        if samples.is_empty() {
            return Self {
                duration_secs,
                avg_hr: 0,
                max_hr: 0,
                min_hr: 0,
                time_in_zone,
            };
        }

        let sum: u32 = samples.iter().map(|s| s.bpm as u32).sum();
        let avg_hr = (sum / samples.len() as u32) as u16;
        let max_hr = samples.iter().map(|s| s.bpm).max().unwrap_or(0);
        let min_hr = samples.iter().map(|s| s.bpm).min().unwrap_or(0);

        Self {
            duration_secs,
            avg_hr,
            max_hr,
            min_hr,
            time_in_zone,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_session_duration() {
        let start = Utc::now();
        let end = start + chrono::Duration::seconds(300);

        let session = CompletedSession {
            id: "test".to_string(),
            plan_name: "Test Plan".to_string(),
            start_time: start,
            end_time: end,
            status: SessionStatus::Completed,
            hr_samples: vec![],
            phases_completed: 1,
            summary: SessionSummary {
                duration_secs: 300,
                avg_hr: 140,
                max_hr: 160,
                min_hr: 120,
                time_in_zone: [0, 300, 0, 0, 0],
            },
        };

        assert_eq!(session.duration_secs(), 300);
        assert!(session.is_completed());
    }

    #[test]
    fn test_summary_from_samples() {
        let now = Utc::now();
        let samples = vec![
            HrSample {
                timestamp: now,
                bpm: 120,
            },
            HrSample {
                timestamp: now,
                bpm: 140,
            },
            HrSample {
                timestamp: now,
                bpm: 160,
            },
        ];

        let summary = SessionSummary::from_samples(&samples, 300, [0, 300, 0, 0, 0]);

        assert_eq!(summary.avg_hr, 140);
        assert_eq!(summary.max_hr, 160);
        assert_eq!(summary.min_hr, 120);
        assert_eq!(summary.duration_secs, 300);
    }

    #[test]
    fn test_summary_from_empty_samples() {
        let summary = SessionSummary::from_samples(&[], 0, [0, 0, 0, 0, 0]);

        assert_eq!(summary.avg_hr, 0);
        assert_eq!(summary.max_hr, 0);
        assert_eq!(summary.min_hr, 0);
    }
}
