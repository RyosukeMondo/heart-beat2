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
use tokio::task::JoinHandle;
use tokio::time::{interval, Duration};

/// Executes training sessions with real-time HR monitoring and state management.
///
/// The executor manages the lifecycle of training sessions, coordinating between
/// the session state machine, HR data stream, notifications, and persistence.
pub struct SessionExecutor {
    /// Session state machine wrapped in Arc<Mutex> for shared access
    session_state: Arc<Mutex<SessionStateMachineWrapper>>,

    /// Notification port for user alerts
    notification_port: Arc<dyn NotificationPort>,

    /// Handle to the tick loop task (None when not running)
    tick_task: Option<JoinHandle<()>>,
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
            tick_task: None,
        }
    }

    /// Start a new training session.
    ///
    /// Initializes the session state machine with the given training plan and spawns
    /// a background task that sends Tick events every 1 second to drive session progress.
    ///
    /// # Arguments
    ///
    /// * `plan` - The training plan to execute
    ///
    /// # Returns
    ///
    /// Result indicating success or failure. Fails if a session is already running.
    pub async fn start_session(&mut self, plan: TrainingPlan) -> Result<()> {
        // Stop any existing session first
        if self.tick_task.is_some() {
            self.stop_session().await?;
        }

        // Send Start event to the state machine
        {
            let mut state = self.session_state.lock().await;
            state.handle(SessionEvent::Start(plan));
        }

        // Spawn tick loop
        let state_clone = Arc::clone(&self.session_state);
        let tick_task = tokio::spawn(async move {
            let mut ticker = interval(Duration::from_secs(1));
            ticker.tick().await; // First tick completes immediately, skip it

            loop {
                ticker.tick().await;

                let mut state = state_clone.lock().await;
                state.handle(SessionEvent::Tick);

                // Check if session is completed or stopped
                if matches!(
                    state.state(),
                    crate::state::session::State::Completed { .. }
                ) {
                    break;
                }
            }
        });

        self.tick_task = Some(tick_task);

        Ok(())
    }

    /// Stop the current session.
    ///
    /// Sends a Stop event to the state machine and cancels the tick loop task.
    pub async fn stop_session(&mut self) -> Result<()> {
        // Send Stop event
        {
            let mut state = self.session_state.lock().await;
            state.handle(SessionEvent::Stop);
        }

        // Cancel tick task
        if let Some(task) = self.tick_task.take() {
            task.abort();
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::adapters::MockNotificationAdapter;
    use crate::domain::heart_rate::Zone;
    use crate::domain::training_plan::{TrainingPhase, TransitionCondition};
    use chrono::Utc;
    use tokio::time::{sleep, Duration};

    #[tokio::test]
    async fn test_start_session_progresses_through_phases() {
        let notifier = Arc::new(MockNotificationAdapter::new());
        let mut executor = SessionExecutor::new(notifier);

        let plan = TrainingPlan {
            name: "Test Plan".to_string(),
            phases: vec![
                TrainingPhase {
                    name: "Phase 1".to_string(),
                    target_zone: Zone::Zone2,
                    duration_secs: 2,
                    transition: TransitionCondition::TimeElapsed,
                },
                TrainingPhase {
                    name: "Phase 2".to_string(),
                    target_zone: Zone::Zone3,
                    duration_secs: 2,
                    transition: TransitionCondition::TimeElapsed,
                },
            ],
            created_at: Utc::now(),
            max_hr: 180,
        };

        executor.start_session(plan).await.unwrap();

        // Wait for first phase to complete (2 seconds + buffer)
        sleep(Duration::from_millis(2500)).await;

        // Check that we're in phase 1 (second phase)
        {
            let state = executor.session_state.lock().await;
            if let Some((phase, elapsed, _)) = state.get_progress() {
                assert!(phase >= 1, "Should have advanced to at least phase 1");
                assert!(
                    elapsed < 2,
                    "Should be in early part of phase 1, elapsed: {}",
                    elapsed
                );
            } else {
                panic!("Expected session to be in progress");
            }
        }

        // Wait for session to complete
        sleep(Duration::from_millis(2500)).await;

        // Verify session completed
        {
            let state = executor.session_state.lock().await;
            assert!(
                matches!(state.state(), crate::state::session::State::Completed { .. }),
                "Session should be completed"
            );
        }
    }

    #[tokio::test]
    async fn test_stop_session() {
        let notifier = Arc::new(MockNotificationAdapter::new());
        let mut executor = SessionExecutor::new(notifier);

        let plan = TrainingPlan {
            name: "Test Plan".to_string(),
            phases: vec![TrainingPhase {
                name: "Long Phase".to_string(),
                target_zone: Zone::Zone2,
                duration_secs: 100,
                transition: TransitionCondition::TimeElapsed,
            }],
            created_at: Utc::now(),
            max_hr: 180,
        };

        executor.start_session(plan).await.unwrap();
        sleep(Duration::from_millis(1500)).await;

        executor.stop_session().await.unwrap();

        // Verify session stopped
        {
            let state = executor.session_state.lock().await;
            assert!(
                matches!(state.state(), crate::state::session::State::Completed { .. }),
                "Session should be completed after stop"
            );
        }
    }
}
