//! Training session state machine using statig.
//!
//! This module implements a state machine for managing training session execution,
//! including phase transitions, progress tracking, and zone deviation detection.

#![allow(missing_docs)] // statig macro generates code that triggers missing_docs warnings

use crate::domain::heart_rate::Zone;
use crate::domain::training_plan::{calculate_zone, TrainingPlan};
use statig::prelude::*;
use std::cmp::Ordering;

/// Events that drive state transitions in the session state machine.
#[derive(Debug, Clone)]
pub enum SessionEvent {
    /// Start a new session with the given training plan
    Start(TrainingPlan),
    /// One-second timer tick for progress tracking
    Tick,
    /// Update current heart rate
    UpdateBpm(u16),
    /// User pauses the session
    Pause,
    /// User resumes a paused session
    Resume,
    /// User stops the session
    Stop,
}

/// Zone deviation status for biofeedback.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ZoneDeviation {
    /// Current heart rate is within the target zone
    InZone,
    /// Heart rate is below the target zone for 5+ seconds
    TooLow,
    /// Heart rate is above the target zone for 5+ seconds
    TooHigh,
}

/// Tracks consecutive seconds outside target zone for deviation detection.
#[derive(Debug, Clone)]
pub struct ZoneTracker {
    /// Consecutive seconds below target zone
    consecutive_low_secs: u32,
    /// Consecutive seconds above target zone
    consecutive_high_secs: u32,
    /// Last emitted deviation state
    last_deviation: ZoneDeviation,
}

impl Default for ZoneTracker {
    fn default() -> Self {
        Self {
            consecutive_low_secs: 0,
            consecutive_high_secs: 0,
            last_deviation: ZoneDeviation::InZone,
        }
    }
}

impl ZoneTracker {
    /// Check current heart rate against target zone and detect deviations.
    ///
    /// Returns Some(deviation) if a new deviation event should be emitted.
    fn check(
        &mut self,
        current_bpm: u16,
        target_zone: Zone,
        max_hr: u16,
    ) -> Option<ZoneDeviation> {
        let current_zone = match calculate_zone(current_bpm, max_hr) {
            Ok(Some(zone)) => zone,
            _ => return None, // Invalid data, don't update state
        };

        match current_zone.cmp(&target_zone) {
            Ordering::Less => {
                self.consecutive_low_secs += 1;
                self.consecutive_high_secs = 0;

                if self.consecutive_low_secs >= 5 && self.last_deviation != ZoneDeviation::TooLow
                {
                    self.last_deviation = ZoneDeviation::TooLow;
                    return Some(ZoneDeviation::TooLow);
                }
            }
            Ordering::Greater => {
                self.consecutive_high_secs += 1;
                self.consecutive_low_secs = 0;

                if self.consecutive_high_secs >= 5
                    && self.last_deviation != ZoneDeviation::TooHigh
                {
                    self.last_deviation = ZoneDeviation::TooHigh;
                    return Some(ZoneDeviation::TooHigh);
                }
            }
            Ordering::Equal => {
                // Always reset counters when in zone
                self.consecutive_low_secs = 0;
                self.consecutive_high_secs = 0;

                // Only emit event if we were previously in a different deviation state
                if self.last_deviation != ZoneDeviation::InZone {
                    self.last_deviation = ZoneDeviation::InZone;
                    return Some(ZoneDeviation::InZone);
                }
            }
        }

        None
    }
}

/// State machine states for training session management.
#[derive(Debug)]
pub enum SessionState {
    /// Initial state - no active session
    Idle,

    /// Session is actively running
    InProgress {
        /// Index of the current phase in the training plan
        current_phase: usize,
        /// Seconds elapsed in the current phase
        elapsed_secs: u32,
        /// Consecutive seconds holding target HR (for HR-based transitions)
        hr_hold_secs: u32,
        /// Zone deviation tracker
        zone_tracker: ZoneTracker,
    },

    /// Session is paused, preserving progress
    Paused {
        /// Index of the phase when paused
        phase: usize,
        /// Seconds elapsed when paused
        elapsed: u32,
        /// Zone tracker state when paused
        zone_tracker: ZoneTracker,
    },

    /// Session completed
    Completed,
}

impl Default for SessionState {
    fn default() -> Self {
        Self::Idle
    }
}

/// State machine implementation using statig
#[state_machine(
    initial = "State::idle()",
    state(derive(Debug)),
    on_transition = "Self::on_transition"
)]
impl SessionState {
    /// Handle idle state
    #[state]
    fn idle(event: &SessionEvent) -> Response<State> {
        match event {
            SessionEvent::Start(_plan) => {
                Transition(State::in_progress(0, 0, 0, ZoneTracker::default()))
            }
            _ => Super,
        }
    }

    /// Handle in-progress state
    #[state]
    fn in_progress(
        current_phase: &usize,
        elapsed_secs: &u32,
        _hr_hold_secs: &u32,
        zone_tracker: &ZoneTracker,
        event: &SessionEvent,
    ) -> Response<State> {
        match event {
            SessionEvent::Pause => {
                Transition(State::paused(*current_phase, *elapsed_secs, zone_tracker.clone()))
            }
            SessionEvent::Stop => Transition(State::completed()),
            _ => Super,
        }
    }

    /// Handle paused state
    #[state]
    fn paused(
        phase: &usize,
        elapsed: &u32,
        zone_tracker: &ZoneTracker,
        event: &SessionEvent,
    ) -> Response<State> {
        match event {
            SessionEvent::Resume => {
                Transition(State::in_progress(*phase, *elapsed, 0, zone_tracker.clone()))
            }
            SessionEvent::Stop => Transition(State::completed()),
            _ => Super,
        }
    }

    /// Handle completed state (terminal state)
    #[state]
    fn completed() -> Response<State> {
        Super
    }

    /// Called on state transitions
    fn on_transition(&mut self, _source: &State, _target: &State) {
        // State transition logic will be implemented in task 1.2
    }
}

/// Shared context for the session state machine.
pub struct SessionContext {
    /// The training plan being executed
    pub plan: Option<TrainingPlan>,
}

impl SessionContext {
    /// Create a new session context
    pub fn new() -> Self {
        Self { plan: None }
    }

    /// Get a reference to the current training plan
    pub fn plan(&self) -> Option<&TrainingPlan> {
        self.plan.as_ref()
    }
}

impl Default for SessionContext {
    fn default() -> Self {
        Self::new()
    }
}

/// Public state machine wrapper
pub struct SessionStateMachineWrapper {
    machine: statig::blocking::InitializedStateMachine<SessionState>,
    context: SessionContext,
}

impl SessionStateMachineWrapper {
    /// Create a new session state machine
    pub fn new() -> Self {
        Self {
            machine: SessionState::default().uninitialized_state_machine().init(),
            context: SessionContext::new(),
        }
    }

    /// Handle an event
    pub fn handle(&mut self, event: SessionEvent) {
        self.machine.handle(&event);
    }

    /// Get current state
    pub fn state(&self) -> &State {
        self.machine.state()
    }

    /// Get context
    pub fn context(&self) -> &SessionContext {
        &self.context
    }

    /// Get mutable context
    pub fn context_mut(&mut self) -> &mut SessionContext {
        &mut self.context
    }
}

impl Default for SessionStateMachineWrapper {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_state_machine_initial_state() {
        let machine = SessionStateMachineWrapper::new();
        assert!(matches!(machine.state(), State::Idle {}));
    }

    #[test]
    fn test_zone_tracker_too_low() {
        let mut tracker = ZoneTracker::default();

        // First 4 seconds below zone - no event
        for _ in 0..4 {
            let result = tracker.check(100, Zone::Zone3, 200);
            assert_eq!(result, None);
        }

        // 5th second below zone - emit TooLow
        let result = tracker.check(100, Zone::Zone3, 200);
        assert_eq!(result, Some(ZoneDeviation::TooLow));

        // Subsequent seconds - no more events until state changes
        let result = tracker.check(100, Zone::Zone3, 200);
        assert_eq!(result, None);
    }

    #[test]
    fn test_zone_tracker_too_high() {
        let mut tracker = ZoneTracker::default();

        // First 4 seconds above zone - no event
        for _ in 0..4 {
            let result = tracker.check(180, Zone::Zone2, 200);
            assert_eq!(result, None);
        }

        // 5th second above zone - emit TooHigh
        let result = tracker.check(180, Zone::Zone2, 200);
        assert_eq!(result, Some(ZoneDeviation::TooHigh));

        // Subsequent seconds - no more events
        let result = tracker.check(180, Zone::Zone2, 200);
        assert_eq!(result, None);
    }

    #[test]
    fn test_zone_tracker_return_to_zone() {
        let mut tracker = ZoneTracker::default();

        // Go too low
        for _ in 0..5 {
            tracker.check(100, Zone::Zone3, 200);
        }

        // Return to zone - emit InZone
        let result = tracker.check(140, Zone::Zone3, 200);
        assert_eq!(result, Some(ZoneDeviation::InZone));

        // Counters should be reset
        assert_eq!(tracker.consecutive_low_secs, 0);
        assert_eq!(tracker.consecutive_high_secs, 0);
    }

    #[test]
    fn test_zone_tracker_alternating() {
        let mut tracker = ZoneTracker::default();

        // Go low for 3 seconds
        for _ in 0..3 {
            tracker.check(100, Zone::Zone3, 200);
        }

        // Return to zone before threshold
        tracker.check(140, Zone::Zone3, 200);

        // Counter should reset
        assert_eq!(tracker.consecutive_low_secs, 0);

        // Go low again - should need full 5 seconds
        for _ in 0..4 {
            let result = tracker.check(100, Zone::Zone3, 200);
            assert_eq!(result, None);
        }
    }
}
