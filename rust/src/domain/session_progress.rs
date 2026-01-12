//! Session progress types for streaming workout state to the UI.
//!
//! This module provides types for real-time session progress updates that can
//! be streamed to Flutter during workout execution. These types are designed
//! to be lightweight and FRB-compatible for efficient cross-language serialization.

use crate::domain::heart_rate::Zone;
use serde::{Deserialize, Serialize};

/// Current state of a workout session for UI updates.
///
/// This type is designed to be streamed to Flutter at regular intervals
/// (typically 1Hz) to provide real-time workout feedback. All fields use
/// simple types compatible with flutter_rust_bridge.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SessionProgress {
    /// Current execution state of the session.
    pub state: SessionState,

    /// Index of the currently executing phase (0-based).
    pub current_phase: u32,

    /// Total elapsed time for the entire session in seconds.
    pub total_elapsed_secs: u32,

    /// Total remaining time for the entire session in seconds.
    pub total_remaining_secs: u32,

    /// Current zone status relative to the target zone.
    pub zone_status: ZoneStatus,

    /// Current heart rate in beats per minute.
    pub current_bpm: u16,

    /// Details about the current phase progress.
    pub phase_progress: PhaseProgress,
}

/// Execution state of a workout session.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SessionState {
    /// Session is actively running.
    Running,

    /// Session is paused by the user.
    Paused,

    /// Session has completed all phases.
    Completed,

    /// Session was stopped by the user.
    Stopped,
}

/// Progress information for the currently executing phase.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PhaseProgress {
    /// Index of this phase in the plan (0-based).
    pub phase_index: u32,

    /// Human-readable name of the phase (e.g., "Warmup", "Work").
    pub phase_name: String,

    /// Target heart rate zone for this phase.
    pub target_zone: Zone,

    /// Time elapsed in this phase in seconds.
    pub elapsed_secs: u32,

    /// Time remaining in this phase in seconds.
    pub remaining_secs: u32,
}

/// Status of current heart rate relative to the target zone.
///
/// Used to provide immediate visual feedback to the user when they
/// need to adjust their effort level.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ZoneStatus {
    /// Heart rate is within the target zone.
    InZone,

    /// Heart rate is below the target zone - user should speed up.
    TooLow,

    /// Heart rate is above the target zone - user should slow down.
    TooHigh,
}

impl SessionProgress {
    /// Calculate the total duration of the session in seconds.
    pub fn total_duration_secs(&self) -> u32 {
        self.total_elapsed_secs + self.total_remaining_secs
    }

    /// Calculate progress through the session as a percentage (0.0 to 1.0).
    pub fn progress_fraction(&self) -> f32 {
        let total = self.total_duration_secs();
        if total == 0 {
            return 0.0;
        }
        self.total_elapsed_secs as f32 / total as f32
    }
}

impl PhaseProgress {
    /// Calculate the total duration of this phase in seconds.
    pub fn duration_secs(&self) -> u32 {
        self.elapsed_secs + self.remaining_secs
    }

    /// Calculate progress through this phase as a percentage (0.0 to 1.0).
    pub fn progress_fraction(&self) -> f32 {
        let total = self.duration_secs();
        if total == 0 {
            return 0.0;
        }
        self.elapsed_secs as f32 / total as f32
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_session_progress_total_duration() {
        let progress = SessionProgress {
            state: SessionState::Running,
            current_phase: 0,
            total_elapsed_secs: 300,
            total_remaining_secs: 600,
            zone_status: ZoneStatus::InZone,
            current_bpm: 140,
            phase_progress: PhaseProgress {
                phase_index: 0,
                phase_name: "Warmup".to_string(),
                target_zone: Zone::Zone2,
                elapsed_secs: 300,
                remaining_secs: 300,
            },
        };

        assert_eq!(progress.total_duration_secs(), 900);
        assert!((progress.progress_fraction() - 0.333).abs() < 0.01);
    }

    #[test]
    fn test_phase_progress_fraction() {
        let phase = PhaseProgress {
            phase_index: 1,
            phase_name: "Work".to_string(),
            target_zone: Zone::Zone4,
            elapsed_secs: 100,
            remaining_secs: 200,
        };

        assert_eq!(phase.duration_secs(), 300);
        assert!((phase.progress_fraction() - 0.333).abs() < 0.01);
    }

    #[test]
    fn test_zone_status_variants() {
        // Ensure all variants can be created and are distinct
        assert_ne!(ZoneStatus::InZone, ZoneStatus::TooLow);
        assert_ne!(ZoneStatus::InZone, ZoneStatus::TooHigh);
        assert_ne!(ZoneStatus::TooLow, ZoneStatus::TooHigh);
    }

    #[test]
    fn test_session_state_variants() {
        // Ensure all variants can be created and are distinct
        assert_ne!(SessionState::Running, SessionState::Paused);
        assert_ne!(SessionState::Running, SessionState::Completed);
        assert_ne!(SessionState::Paused, SessionState::Stopped);
    }
}
