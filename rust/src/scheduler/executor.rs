//! Session executor for running training sessions with real-time HR monitoring.
//!
//! This module implements `SessionExecutor`, which manages the lifecycle of training
//! sessions including starting/stopping, tick-based progress tracking, HR data integration,
//! session persistence, and cron-based scheduling.

use crate::domain::training_plan::TrainingPlan;
use crate::ports::notification::NotificationPort;
use crate::state::session::{SessionEvent, SessionStateMachineWrapper};
use anyhow::Result;
use std::sync::Arc;
use tokio::sync::Mutex;

/// Executes training sessions with real-time HR monitoring and state management.
///
/// The executor manages the lifecycle of training sessions, coordinating between
/// the session state machine, HR data stream, notifications, and persistence.
pub struct SessionExecutor {
    /// Session state machine wrapped in Arc<Mutex> for shared access
    session_state: Arc<Mutex<SessionStateMachineWrapper>>,

    /// Notification port for user alerts
    notification_port: Arc<dyn NotificationPort>,
}

impl SessionExecutor {
    /// Create a new session executor.
    ///
    /// # Arguments
    ///
    /// * `notification_port` - Port for sending notifications to the user
    pub fn new(notification_port: Arc<dyn NotificationPort>) -> Self {
        Self {
            session_state: Arc::new(Mutex::new(SessionStateMachineWrapper::new())),
            notification_port,
        }
    }
}
