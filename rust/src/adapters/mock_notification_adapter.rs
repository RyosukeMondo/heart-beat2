//! Mock notification adapter for testing.
//!
//! This module provides a mock implementation of the NotificationPort trait that
//! records all notifications for testing purposes. It allows tests to verify that
//! the correct notifications are emitted in response to domain events.

use crate::ports::notification::{NotificationEvent, NotificationPort};
use anyhow::Result;
use async_trait::async_trait;
use std::sync::Arc;
use tokio::sync::Mutex;

/// Mock notification adapter that records all notifications.
///
/// This adapter stores all `notify()` calls in a thread-safe vector, allowing
/// tests to assert on notification behavior without requiring a real UI or
/// output mechanism. This is essential for testing domain logic that emits
/// notifications.
///
/// # Example
///
/// ```rust
/// use heart_beat::adapters::mock_notification_adapter::MockNotificationAdapter;
/// use heart_beat::ports::notification::{NotificationEvent, NotificationPort};
///
/// #[tokio::main]
/// async fn main() {
///     let adapter = MockNotificationAdapter::new();
///
///     // Emit some notifications
///     adapter.notify(NotificationEvent::ConnectionLost).await.unwrap();
///
///     // Assert on recorded events
///     let events = adapter.get_events().await;
///     assert_eq!(events.len(), 1);
///     assert!(matches!(events[0], NotificationEvent::ConnectionLost));
/// }
/// ```
#[derive(Debug, Clone)]
pub struct MockNotificationAdapter {
    /// Thread-safe storage for recorded notification events
    events: Arc<Mutex<Vec<NotificationEvent>>>,
}

impl MockNotificationAdapter {
    /// Create a new mock notification adapter.
    ///
    /// The adapter starts with an empty event list.
    pub fn new() -> Self {
        Self {
            events: Arc::new(Mutex::new(Vec::new())),
        }
    }

    /// Get a copy of all recorded notification events.
    ///
    /// Returns the events in the order they were received. This method
    /// clones the events to avoid holding the lock during test assertions.
    pub async fn get_events(&self) -> Vec<NotificationEvent> {
        self.events.lock().await.clone()
    }

    /// Clear all recorded events.
    ///
    /// Useful for resetting the mock between test cases or test phases.
    pub async fn clear_events(&self) {
        self.events.lock().await.clear();
    }

    /// Get the number of recorded events without cloning.
    ///
    /// More efficient than `get_events().len()` when you only need the count.
    pub async fn event_count(&self) -> usize {
        self.events.lock().await.len()
    }
}

impl Default for MockNotificationAdapter {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait]
impl NotificationPort for MockNotificationAdapter {
    async fn notify(&self, event: NotificationEvent) -> Result<()> {
        self.events.lock().await.push(event);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::heart_rate::Zone;
    use crate::state::session::ZoneDeviation;

    #[tokio::test]
    async fn test_records_single_event() {
        let adapter = MockNotificationAdapter::new();

        adapter.notify(NotificationEvent::ConnectionLost).await.unwrap();

        let events = adapter.get_events().await;
        assert_eq!(events.len(), 1);
        assert!(matches!(events[0], NotificationEvent::ConnectionLost));
    }

    #[tokio::test]
    async fn test_records_multiple_events_in_order() {
        let adapter = MockNotificationAdapter::new();

        adapter.notify(NotificationEvent::BatteryLow { percentage: 15 }).await.unwrap();
        adapter.notify(NotificationEvent::ConnectionLost).await.unwrap();
        adapter.notify(NotificationEvent::WorkoutReady {
            plan_name: "Test Plan".to_string(),
        }).await.unwrap();

        let events = adapter.get_events().await;
        assert_eq!(events.len(), 3);
        assert!(matches!(events[0], NotificationEvent::BatteryLow { percentage: 15 }));
        assert!(matches!(events[1], NotificationEvent::ConnectionLost));
        assert!(matches!(events[2], NotificationEvent::WorkoutReady { .. }));
    }

    #[tokio::test]
    async fn test_clear_events() {
        let adapter = MockNotificationAdapter::new();

        adapter.notify(NotificationEvent::ConnectionLost).await.unwrap();
        assert_eq!(adapter.event_count().await, 1);

        adapter.clear_events().await;
        assert_eq!(adapter.event_count().await, 0);
    }

    #[tokio::test]
    async fn test_zone_deviation_event() {
        let adapter = MockNotificationAdapter::new();

        adapter.notify(NotificationEvent::ZoneDeviation {
            deviation: ZoneDeviation::TooHigh,
            current_bpm: 180,
            target_zone: Zone::Zone2,
        }).await.unwrap();

        let events = adapter.get_events().await;
        assert_eq!(events.len(), 1);

        match &events[0] {
            NotificationEvent::ZoneDeviation { deviation, current_bpm, target_zone } => {
                assert_eq!(*deviation, ZoneDeviation::TooHigh);
                assert_eq!(*current_bpm, 180);
                assert_eq!(*target_zone, Zone::Zone2);
            }
            _ => panic!("Expected ZoneDeviation event"),
        }
    }

    #[tokio::test]
    async fn test_phase_transition_event() {
        let adapter = MockNotificationAdapter::new();

        adapter.notify(NotificationEvent::PhaseTransition {
            from_phase: 0,
            to_phase: 1,
            phase_name: "Main Set".to_string(),
        }).await.unwrap();

        let events = adapter.get_events().await;
        match &events[0] {
            NotificationEvent::PhaseTransition { from_phase, to_phase, phase_name } => {
                assert_eq!(*from_phase, 0);
                assert_eq!(*to_phase, 1);
                assert_eq!(phase_name, "Main Set");
            }
            _ => panic!("Expected PhaseTransition event"),
        }
    }
}
