//! Notification Port
//!
//! This module defines the `NotificationPort` trait, which abstracts notification
//! operations for biofeedback and alerts. This allows the domain logic to emit
//! notifications without coupling to specific UI frameworks or output mechanisms.

use crate::domain::heart_rate::Zone;
use crate::state::session::ZoneDeviation;
use anyhow::Result;
use async_trait::async_trait;
use serde::Serialize;

/// Abstraction for notification operations to enable testability and swappable implementations.
///
/// This trait defines the interface for all notification-related operations including
/// biofeedback alerts (zone deviations), phase transitions, battery warnings, and
/// connection status. It is implemented by various adapters (mock, CLI, Flutter) that
/// provide different notification mechanisms.
#[async_trait]
pub trait NotificationPort: Send + Sync {
    /// Send a notification for the given event.
    ///
    /// This method is called by the domain logic when an event occurs that requires
    /// user notification. Implementations determine how to present the notification
    /// (audio tone, visual alert, haptic feedback, log, etc.).
    ///
    /// # Arguments
    ///
    /// * `event` - The notification event to be processed
    ///
    /// # Errors
    ///
    /// Returns an error if the notification fails to be delivered. Implementations
    /// should be resilient and avoid blocking the caller.
    async fn notify(&self, event: NotificationEvent) -> Result<()>;
}

/// Events that trigger user notifications.
///
/// Each variant represents a specific type of notification with associated data.
/// These events are emitted by the domain logic (session state machine, device
/// monitoring, etc.) and handled by notification adapters.
#[derive(Debug, Clone, Serialize)]
#[serde(tag = "type")]
pub enum NotificationEvent {
    /// Heart rate has deviated from the target zone.
    ///
    /// This event is triggered when the user's heart rate is too high or too low
    /// relative to the current training phase's target zone for a sustained period
    /// (typically 5+ seconds).
    ZoneDeviation {
        /// Type of deviation (too low, too high, or back in zone)
        deviation: ZoneDeviation,
        /// Current heart rate in beats per minute
        current_bpm: u16,
        /// The target zone for the current training phase
        target_zone: Zone,
    },

    /// Training phase transition.
    ///
    /// This event is triggered when the workout advances to a new phase
    /// (e.g., warmup → main → cooldown).
    PhaseTransition {
        /// Index of the previous phase
        from_phase: usize,
        /// Index of the new phase
        to_phase: usize,
        /// Name/description of the new phase
        phase_name: String,
    },

    /// Device battery level is low.
    ///
    /// This event is triggered when the connected heart rate monitor's battery
    /// drops below a threshold (e.g., 20%).
    BatteryLow {
        /// Battery level as a percentage (0-100)
        percentage: u8,
    },

    /// Connection to the heart rate device has been lost.
    ///
    /// This event is triggered when the BLE connection to the heart rate monitor
    /// is unexpectedly disconnected during a workout.
    ConnectionLost,

    /// Workout is ready to start.
    ///
    /// This event is triggered when all prerequisites are met (device connected,
    /// plan loaded) and the workout is ready to begin.
    WorkoutReady {
        /// Name of the training plan loaded
        plan_name: String,
    },
}
