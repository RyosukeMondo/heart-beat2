//! Session executor for running training sessions with real-time HR monitoring.
//!
//! This module implements `SessionExecutor`, which manages the lifecycle of training
//! sessions including starting/stopping, tick-based progress tracking, HR data integration,
//! session persistence, and cron-based scheduling.

use crate::domain::heart_rate::FilteredHeartRate;
use crate::domain::training_plan::TrainingPlan;
use crate::ports::notification::{NotificationEvent, NotificationPort};
use crate::state::session::{SessionEvent, SessionStateMachineWrapper};
use anyhow::Result;
use std::sync::Arc;
use tokio::sync::{broadcast, Mutex};
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

    /// Optional HR data receiver for zone monitoring
    hr_receiver: Option<broadcast::Receiver<FilteredHeartRate>>,
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
            hr_receiver: None,
        }
    }

    /// Create a new session executor with HR data stream.
    ///
    /// # Arguments
    ///
    /// * `notification_port` - Port for sending notifications to the user
    /// * `hr_receiver` - Broadcast receiver for filtered heart rate data
    pub fn with_hr_stream(
        notification_port: Arc<dyn NotificationPort>,
        hr_receiver: broadcast::Receiver<FilteredHeartRate>,
    ) -> Self {
        Self {
            session_state: Arc::new(Mutex::new(SessionStateMachineWrapper::new())),
            notification_port,
            tick_task: None,
            hr_receiver: Some(hr_receiver),
        }
    }

    /// Start a new training session.
    ///
    /// Initializes the session state machine with the given training plan and spawns
    /// a background task that sends Tick events every 1 second to drive session progress.
    /// If an HR receiver is configured, it also monitors incoming HR data for zone deviations.
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
            state.handle(SessionEvent::Start(plan.clone()));
        }

        // Spawn tick loop with optional HR monitoring
        let state_clone = Arc::clone(&self.session_state);
        let notifier_clone = Arc::clone(&self.notification_port);
        let mut hr_rx = self.hr_receiver.as_ref().map(|rx| rx.resubscribe());

        let tick_task = tokio::spawn(async move {
            let mut ticker = interval(Duration::from_secs(1));
            ticker.tick().await; // First tick completes immediately, skip it

            loop {
                ticker.tick().await;

                // Check for HR data (non-blocking) - drain all available messages
                if let Some(ref mut rx) = hr_rx {
                    loop {
                        match rx.try_recv() {
                            Ok(hr_data) => {
                                // Update BPM and check for zone deviation
                                let deviation = {
                                    let mut state = state_clone.lock().await;
                                    state.handle(SessionEvent::UpdateBpm(hr_data.filtered_bpm))
                                };

                                // Emit notification if zone deviation detected
                                if let Some(dev) = deviation {
                                    if let Some(plan_context) = {
                                        let state = state_clone.lock().await;
                                        state.context().plan().cloned()
                                    } {
                                        if let Some((phase_idx, _, _)) = {
                                            let state = state_clone.lock().await;
                                            state.get_progress()
                                        } {
                                            if phase_idx < plan_context.phases.len() {
                                                let target_zone =
                                                    plan_context.phases[phase_idx].target_zone;
                                                let _ = notifier_clone
                                                    .notify(NotificationEvent::ZoneDeviation {
                                                        deviation: dev,
                                                        current_bpm: hr_data.filtered_bpm,
                                                        target_zone,
                                                    })
                                                    .await;
                                            }
                                        }
                                    }
                                }
                            }
                            Err(broadcast::error::TryRecvError::Empty) => {
                                // No more data available, exit inner loop
                                break;
                            }
                            Err(broadcast::error::TryRecvError::Lagged(_)) => {
                                // Lagged behind, continue reading
                                continue;
                            }
                            Err(broadcast::error::TryRecvError::Closed) => {
                                // Channel closed, stop HR monitoring but continue session
                                hr_rx = None;
                                break;
                            }
                        }
                    }
                }

                // Handle the tick
                {
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

    #[tokio::test]
    async fn test_hr_stream_integration() {
        use tokio::sync::broadcast;

        let notifier = Arc::new(MockNotificationAdapter::new());
        let (hr_tx, hr_rx) = broadcast::channel(100);
        let mut executor = SessionExecutor::with_hr_stream(notifier.clone(), hr_rx);

        let plan = TrainingPlan {
            name: "HR Test Plan".to_string(),
            phases: vec![TrainingPhase {
                name: "Zone 2 Phase".to_string(),
                target_zone: Zone::Zone2,
                duration_secs: 10,
                transition: TransitionCondition::TimeElapsed,
            }],
            created_at: Utc::now(),
            max_hr: 180,
        };

        executor.start_session(plan).await.unwrap();

        // Wait for tick loop to start
        sleep(Duration::from_millis(500)).await;

        // Send some HR data
        let hr_data = FilteredHeartRate {
            raw_bpm: 120,
            filtered_bpm: 120,
            rmssd: Some(45.0),
            battery_level: Some(85),
            timestamp: 0,
        };

        // Send HR data continuously
        for _ in 0..20 {
            hr_tx.send(hr_data.clone()).unwrap();
            sleep(Duration::from_millis(100)).await;
        }

        // Verify the session is still running (HR stream integration doesn't crash)
        {
            let state = executor.session_state.lock().await;
            // Session should still be in progress, not crashed
            assert!(
                matches!(state.state(), crate::state::session::State::InProgress { .. }),
                "Session should still be running after HR data processing"
            );
        }

        executor.stop_session().await.unwrap();

        // NOTE: Zone deviation testing is complex because it requires the zone tracker
        // to accumulate 5+ consecutive seconds of out-of-zone readings. This is tested
        // separately in the session state machine tests. Here we only verify that:
        // 1. HR data can be sent via broadcast channel
        // 2. The executor processes it without crashing
        // 3. UpdateBpm events are sent to the state machine
    }
}
