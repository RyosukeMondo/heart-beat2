//! Coaching cue types and context.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// A coaching directive — the output of the rule engine.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Cue {
    pub id: uuid::Uuid,
    pub source: CueSource,
    pub label: String,
    pub message: String,
    pub priority: CuePriority,
    pub generated_at: DateTime<Utc>,
}

impl Cue {
    pub fn new(source: CueSource, label: impl Into<String>, message: impl Into<String>, priority: CuePriority) -> Self {
        Self {
            id: uuid::Uuid::new_v4(),
            source,
            label: label.into(),
            message: message.into(),
            priority,
            generated_at: Utc::now(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Serialize, Deserialize)]
pub enum CuePriority {
    Low = 0,
    Normal = 1,
    High = 2,
    Critical = 3,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum CueSource {
    TargetZone,
    Inactivity,
    Overwork,
}

/// Shared context passed to every rule on each evaluation.
///
/// The context carries the current HR sample and any accumulated state
/// that rules may need to make decisions.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CueContext {
    /// The current HR sample.
    pub sample: crate::domain::HrSample,
    /// Rolling average HR over the last N seconds (for smoothing).
    pub rolling_avg_bpm: f64,
    /// Seconds the current HR has been outside the target zone.
    pub zone_violation_secs: f64,
    /// Seconds HR has been above the overwork threshold.
    pub overwork_secs: f64,
    /// Seconds HR has been below the inactivity threshold.
    pub inactivity_secs: f64,
    /// Whether the HR stream is currently stale (connection lost).
    pub is_stale: bool,
    /// Whether do-not-disturb is currently active.
    pub dnd_active: bool,
    /// The do-not-disturb window configuration.
    pub dnd_window: DoNotDisturbWindow,
}

/// A do-not-disturb window configuration.
///
/// During the window, audio/notification cues are suppressed.
/// In-app display cues are still allowed.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct DoNotDisturbWindow {
    /// Hour of day when DND starts (0–23).
    pub start_hour: u8,
    /// Hour of day when DND ends (0–23).
    pub end_hour: u8,
    /// Time zone offset in seconds from UTC.
    pub tz_offset_secs: i32,
}

impl Default for DoNotDisturbWindow {
    fn default() -> Self {
        Self {
            start_hour: 22,
            end_hour: 7,
            tz_offset_secs: 0,
        }
    }
}

impl DoNotDisturbWindow {
    /// Returns true if DND is currently active given the local time.
    pub fn is_active(&self, local_hour: u8) -> bool {
        if self.start_hour < self.end_hour {
            // Simple case: e.g. 09:00–17:00
            self.start_hour <= local_hour && local_hour < self.end_hour
        } else {
            // Overnight case: e.g. 22:00–07:00
            local_hour >= self.start_hour || local_hour < self.end_hour
        }
    }
}

/// Tracks when each cue label was last emitted, to enforce cadence throttling.
#[derive(Default)]
pub struct CueCadence {
    /// Map from cue label → last-emitted timestamp.
    last_emitted: std::collections::HashMap<String, DateTime<Utc>>,
    /// Minimum interval between repeated cues of the same label.
    min_interval_secs: i64,
}

impl CueCadence {
    pub fn new(min_interval_secs: i64) -> Self {
        Self {
            last_emitted: Default::default(),
            min_interval_secs,
        }
    }

    /// Returns true if the given cue label can be emitted (not throttled).
    pub fn can_emit(&self, label: &str, now: DateTime<Utc>) -> bool {
        match self.last_emitted.get(label) {
            Some(last) => {
                let elapsed = now.signed_duration_since(*last).num_seconds();
                elapsed >= self.min_interval_secs
            }
            None => true,
        }
    }

    /// Record that a cue with the given label was just emitted.
    pub fn record(&mut self, label: &str, now: DateTime<Utc>) {
        self.last_emitted.insert(label.to_string(), now);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_dnd_overnight() {
        let dnd = DoNotDisturbWindow {
            start_hour: 22,
            end_hour: 7,
            tz_offset_secs: 0,
        };
        assert!(dnd.is_active(23));
        assert!(dnd.is_active(0));
        assert!(dnd.is_active(6));
        assert!(!dnd.is_active(7));
        assert!(!dnd.is_active(21));
    }

    #[test]
    fn test_dnd_daytime() {
        let dnd = DoNotDisturbWindow {
            start_hour: 9,
            end_hour: 17,
            tz_offset_secs: 0,
        };
        assert!(!dnd.is_active(8));
        assert!(dnd.is_active(12));
        assert!(dnd.is_active(16));
        assert!(!dnd.is_active(17));
    }

    #[test]
    fn test_cadence_throttle() {
        let mut cadence = CueCadence::new(120); // 2 min minimum
        let now = Utc::now();

        // First emission should always be allowed
        assert!(cadence.can_emit("raise_hr", now));

        // Record the emission — now throttle kicks in
        cadence.record("raise_hr", now);

        // Second emission immediately should be blocked
        assert!(!cadence.can_emit("raise_hr", now));

        // Different label should be allowed
        assert!(cadence.can_emit("cool_down", now));
    }
}