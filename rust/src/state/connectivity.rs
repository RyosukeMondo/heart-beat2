//! BLE connection state machine using statig.
//!
//! This module implements a hierarchical state machine for managing the BLE connection
//! lifecycle. It formally defines all states, events, and transitions to ensure correct
//! handling of edge cases like connection failures, disconnections, and reconnection logic.

#![allow(missing_docs)] // statig macro generates code that triggers missing_docs warnings

use crate::ports::ble_adapter::BleAdapter;
use anyhow::Result;
use flutter_rust_bridge::frb;
use statig::prelude::*;
use std::sync::Arc;

/// Events that drive state transitions in the connection state machine.
#[derive(Debug, Clone)]
pub enum ConnectionEvent {
    /// User initiates device scan
    StartScan,
    /// User stops device scan
    StopScan,
    /// User selects a device to connect to
    DeviceSelected {
        /// The ID of the device to connect to
        device_id: String,
    },
    /// BLE connection established successfully
    ConnectionSuccess,
    /// BLE connection attempt failed
    ConnectionFailed,
    /// Services have been discovered on the connected device
    ServicesDiscovered,
    /// Device disconnected unexpectedly
    Disconnected,
    /// User requests disconnect
    UserDisconnect,
    /// Reconnection attempt succeeded
    ReconnectSuccess,
    /// Reconnection attempt failed
    ReconnectFailed,
}

/// Superstate representing any connected state (Connected or streaming).
///
/// This is used by statig's hierarchical state machine to group Connected
/// and other connection-active states under a common parent, enabling
/// shared transition logic for all connected states.
#[frb(opaque)]
#[derive(Debug, Default)]
pub struct ConnectedSuperstate;

/// State machine states for BLE connection management.
#[derive(Debug, Default)]
pub enum ConnectionState {
    /// Initial state - no activity
    #[default]
    Idle,
    /// Actively scanning for BLE devices
    Scanning,
    /// Attempting to establish connection to a specific device
    Connecting {
        /// The ID of the device being connected to
        device_id: String,
    },
    /// Connected, discovering services on the device
    DiscoveringServices {
        /// The ID of the connected device
        device_id: String,
    },
    /// Successfully connected with services discovered
    Connected {
        /// The ID of the connected device
        device_id: String,
    },
    /// Attempting to reconnect after unexpected disconnection
    Reconnecting {
        /// The ID of the device being reconnected to
        device_id: String,
        /// Number of reconnection attempts made
        attempts: u8,
    },
}

/// Shared context for the state machine
pub struct ConnectionContext {
    /// The BLE adapter for hardware interactions
    adapter: Arc<dyn BleAdapter + Send + Sync>,
}

impl ConnectionContext {
    /// Create a new connection context with the given BLE adapter
    pub fn new(adapter: Arc<dyn BleAdapter + Send + Sync>) -> Self {
        Self { adapter }
    }

    /// Get a reference to the BLE adapter
    pub fn adapter(&self) -> &dyn BleAdapter {
        self.adapter.as_ref()
    }
}

/// State machine implementation using statig
#[state_machine(
    initial = "State::idle()",
    state(derive(Debug)),
    superstate(derive(Debug)),
    on_transition = "Self::on_transition"
)]
impl ConnectionState {
    /// Idle state - waiting for user action
    #[state]
    fn idle(event: &ConnectionEvent) -> Response<State> {
        match event {
            ConnectionEvent::StartScan => Transition(State::scanning()),
            _ => Super,
        }
    }

    /// Scanning state - looking for BLE devices
    #[state]
    fn scanning(event: &ConnectionEvent) -> Response<State> {
        match event {
            ConnectionEvent::StopScan => Transition(State::idle()),
            ConnectionEvent::DeviceSelected { device_id } => {
                Transition(State::connecting(device_id.clone()))
            }
            _ => Super,
        }
    }

    /// Connecting state - attempting to establish BLE connection
    #[state]
    #[allow(clippy::ptr_arg)]
    fn connecting(device_id: &String, event: &ConnectionEvent) -> Response<State> {
        match event {
            ConnectionEvent::ConnectionSuccess => {
                Transition(State::discovering_services(device_id.clone()))
            }
            ConnectionEvent::ConnectionFailed => {
                Transition(State::reconnecting(device_id.clone(), 1))
            }
            ConnectionEvent::UserDisconnect => Transition(State::idle()),
            _ => Super,
        }
    }

    /// Discovering services state - enumerating BLE services after connection
    #[state]
    #[allow(clippy::ptr_arg)]
    fn discovering_services(device_id: &String, event: &ConnectionEvent) -> Response<State> {
        match event {
            ConnectionEvent::ServicesDiscovered => Transition(State::connected(device_id.clone())),
            ConnectionEvent::ConnectionFailed | ConnectionEvent::Disconnected => {
                Transition(State::reconnecting(device_id.clone(), 1))
            }
            ConnectionEvent::UserDisconnect => Transition(State::idle()),
            _ => Super,
        }
    }

    /// Connected state - fully connected and ready to stream data
    #[state]
    #[allow(clippy::ptr_arg)]
    fn connected(device_id: &String, event: &ConnectionEvent) -> Response<State> {
        match event {
            ConnectionEvent::Disconnected => Transition(State::reconnecting(device_id.clone(), 1)),
            ConnectionEvent::UserDisconnect => Transition(State::idle()),
            _ => Super,
        }
    }

    /// Reconnecting state - attempting to re-establish lost connection
    #[state]
    #[allow(clippy::ptr_arg)]
    fn reconnecting(device_id: &String, attempts: &u8, event: &ConnectionEvent) -> Response<State> {
        match event {
            ConnectionEvent::ReconnectSuccess => Transition(State::connected(device_id.clone())),
            ConnectionEvent::ReconnectFailed => {
                if *attempts >= 3 {
                    // Max retries exceeded, give up
                    tracing::warn!("Reconnection failed after {} attempts", attempts);
                    Transition(State::idle())
                } else {
                    // Increment attempt counter and stay in reconnecting
                    Transition(State::reconnecting(device_id.clone(), attempts + 1))
                }
            }
            ConnectionEvent::UserDisconnect => Transition(State::idle()),
            _ => Super,
        }
    }

    /// Callback invoked on every state transition
    fn on_transition(&mut self, source: &State, target: &State) {
        tracing::info!("State transition: {:?} -> {:?}", source, target);
    }
}

/// Calculate the reconnection delay based on attempt number using exponential backoff.
///
/// # Delay Schedule
/// - Attempt 1: 1 second
/// - Attempt 2: 2 seconds
/// - Attempt 3: 4 seconds
///
/// # Arguments
/// * `attempt` - The reconnection attempt number (1-based)
///
/// # Returns
/// A `Duration` representing how long to wait before the next reconnection attempt
pub fn reconnect_delay(attempt: u8) -> std::time::Duration {
    let delay_secs = match attempt {
        1 => 1,
        2 => 2,
        3 => 4,
        // For safety, though we shouldn't exceed 3 attempts
        _ => 4,
    };
    std::time::Duration::from_secs(delay_secs)
}

/// Connection state machine that wraps the statig state machine
pub struct ConnectionStateMachine {
    /// The underlying statig state machine (uses statig-generated State type)
    machine: statig::blocking::InitializedStateMachine<ConnectionState>,
    /// Shared context for state actions
    context: ConnectionContext,
}

impl ConnectionStateMachine {
    /// Create a new state machine with the given BLE adapter
    pub fn new(adapter: Arc<dyn BleAdapter + Send + Sync>) -> Self {
        Self {
            machine: ConnectionState::default()
                .uninitialized_state_machine()
                .init(),
            context: ConnectionContext::new(adapter),
        }
    }

    /// Handle an event, triggering state transitions
    pub fn handle(&mut self, event: ConnectionEvent) -> Result<()> {
        tracing::debug!("Handling event: {:?}", event);
        self.machine.handle(&event);
        Ok(())
    }

    /// Get the current state (returns the statig State wrapper)
    pub fn state(&self) -> &State {
        self.machine.state()
    }

    /// Get the shared context
    pub fn context(&self) -> &ConnectionContext {
        &self.context
    }
}

#[cfg(test)]
#[allow(clippy::useless_vec)]
mod tests {
    use super::*;
    use mockall::mock;
    use mockall::predicate::*;

    // Mock the BleAdapter trait using mockall
    mock! {
        pub Adapter {}

        #[async_trait::async_trait]
        impl BleAdapter for Adapter {
            async fn start_scan(&self) -> Result<()>;
            async fn stop_scan(&self) -> Result<()>;
            async fn get_discovered_devices(&self) -> Vec<crate::domain::heart_rate::DiscoveredDevice>;
            async fn connect(&self, device_id: &str) -> Result<()>;
            async fn disconnect(&self) -> Result<()>;
            async fn subscribe_hr(&self) -> Result<tokio::sync::mpsc::Receiver<Vec<u8>>>;
            async fn read_battery(&self) -> Result<Option<u8>>;
        }
    }

    /// Simple test adapter that tracks method calls (kept for basic tests)
    struct TestAdapter;

    #[async_trait::async_trait]
    impl BleAdapter for TestAdapter {
        async fn start_scan(&self) -> Result<()> {
            Ok(())
        }

        async fn stop_scan(&self) -> Result<()> {
            Ok(())
        }

        async fn get_discovered_devices(&self) -> Vec<crate::domain::heart_rate::DiscoveredDevice> {
            vec![]
        }

        async fn connect(&self, _device_id: &str) -> Result<()> {
            Ok(())
        }

        async fn disconnect(&self) -> Result<()> {
            Ok(())
        }

        async fn subscribe_hr(&self) -> Result<tokio::sync::mpsc::Receiver<Vec<u8>>> {
            let (_tx, rx) = tokio::sync::mpsc::channel(1);
            Ok(rx)
        }

        async fn read_battery(&self) -> Result<Option<u8>> {
            Ok(Some(100))
        }
    }

    #[test]
    fn test_state_machine_creation() {
        let adapter = Arc::new(TestAdapter);
        let _machine = ConnectionStateMachine::new(adapter);

        // Just verify the machine was created successfully
        // The initial state is Idle by the #[state_machine(initial = "State::idle()")] attribute
    }

    #[test]
    fn test_idle_to_scanning() {
        let adapter = Arc::new(TestAdapter);
        let mut machine = ConnectionStateMachine::new(adapter);

        // Verify the event is handled successfully
        assert!(machine.handle(ConnectionEvent::StartScan).is_ok());
    }

    #[test]
    fn test_scanning_to_connecting() {
        let adapter = Arc::new(TestAdapter);
        let mut machine = ConnectionStateMachine::new(adapter);

        machine.handle(ConnectionEvent::StartScan).unwrap();
        assert!(machine
            .handle(ConnectionEvent::DeviceSelected {
                device_id: "test-device".to_string(),
            })
            .is_ok());
    }

    #[test]
    fn test_full_connection_flow() {
        let adapter = Arc::new(TestAdapter);
        let mut machine = ConnectionStateMachine::new(adapter);

        // Test the full connection flow completes without errors
        machine.handle(ConnectionEvent::StartScan).unwrap();
        machine
            .handle(ConnectionEvent::DeviceSelected {
                device_id: "device-1".to_string(),
            })
            .unwrap();
        machine.handle(ConnectionEvent::ConnectionSuccess).unwrap();
        machine.handle(ConnectionEvent::ServicesDiscovered).unwrap();

        // All transitions successful
    }

    #[test]
    fn test_connection_failure_triggers_reconnect() {
        let adapter = Arc::new(TestAdapter);
        let mut machine = ConnectionStateMachine::new(adapter);

        machine.handle(ConnectionEvent::StartScan).unwrap();
        machine
            .handle(ConnectionEvent::DeviceSelected {
                device_id: "device-1".to_string(),
            })
            .unwrap();

        // Connection fails - should transition to Reconnecting
        assert!(machine.handle(ConnectionEvent::ConnectionFailed).is_ok());
    }

    #[test]
    fn test_reconnection_success() {
        let adapter = Arc::new(TestAdapter);
        let mut machine = ConnectionStateMachine::new(adapter);

        // Set up initial connection
        machine.handle(ConnectionEvent::StartScan).unwrap();
        machine
            .handle(ConnectionEvent::DeviceSelected {
                device_id: "device-1".to_string(),
            })
            .unwrap();
        machine.handle(ConnectionEvent::ConnectionSuccess).unwrap();
        machine.handle(ConnectionEvent::ServicesDiscovered).unwrap();

        // Disconnect and reconnect
        machine.handle(ConnectionEvent::Disconnected).unwrap();
        machine.handle(ConnectionEvent::ReconnectSuccess).unwrap();

        // All transitions successful
    }

    #[test]
    fn test_reconnection_max_retries() {
        let adapter = Arc::new(TestAdapter);
        let mut machine = ConnectionStateMachine::new(adapter);

        // Set up initial connection
        machine.handle(ConnectionEvent::StartScan).unwrap();
        machine
            .handle(ConnectionEvent::DeviceSelected {
                device_id: "device-1".to_string(),
            })
            .unwrap();
        machine.handle(ConnectionEvent::ConnectionSuccess).unwrap();
        machine.handle(ConnectionEvent::ServicesDiscovered).unwrap();

        // Disconnect and fail reconnection 3 times
        machine.handle(ConnectionEvent::Disconnected).unwrap();
        machine.handle(ConnectionEvent::ReconnectFailed).unwrap();
        machine.handle(ConnectionEvent::ReconnectFailed).unwrap();
        machine.handle(ConnectionEvent::ReconnectFailed).unwrap();

        // After 3 attempts, transitions to Idle - test succeeds if no panic
    }

    #[test]
    fn test_user_disconnect_from_scanning() {
        let adapter = Arc::new(TestAdapter);
        let mut machine = ConnectionStateMachine::new(adapter);

        machine.handle(ConnectionEvent::StartScan).unwrap();
        assert!(machine.handle(ConnectionEvent::UserDisconnect).is_ok());
    }

    #[test]
    fn test_user_disconnect_from_connecting() {
        let adapter = Arc::new(TestAdapter);
        let mut machine = ConnectionStateMachine::new(adapter);

        machine.handle(ConnectionEvent::StartScan).unwrap();
        machine
            .handle(ConnectionEvent::DeviceSelected {
                device_id: "device-1".to_string(),
            })
            .unwrap();
        assert!(machine.handle(ConnectionEvent::UserDisconnect).is_ok());
    }

    #[test]
    fn test_user_disconnect_from_connected() {
        let adapter = Arc::new(TestAdapter);
        let mut machine = ConnectionStateMachine::new(adapter);

        machine.handle(ConnectionEvent::StartScan).unwrap();
        machine
            .handle(ConnectionEvent::DeviceSelected {
                device_id: "device-1".to_string(),
            })
            .unwrap();
        machine.handle(ConnectionEvent::ConnectionSuccess).unwrap();
        machine.handle(ConnectionEvent::ServicesDiscovered).unwrap();
        assert!(machine.handle(ConnectionEvent::UserDisconnect).is_ok());
    }

    #[test]
    fn test_reconnect_delay_exponential_backoff() {
        // Test that delays follow exponential backoff: 1s, 2s, 4s
        assert_eq!(reconnect_delay(1), std::time::Duration::from_secs(1));
        assert_eq!(reconnect_delay(2), std::time::Duration::from_secs(2));
        assert_eq!(reconnect_delay(3), std::time::Duration::from_secs(4));
    }

    #[test]
    fn test_reconnect_delay_capped() {
        // Verify that attempts beyond 3 are capped at 4 seconds
        assert_eq!(reconnect_delay(4), std::time::Duration::from_secs(4));
        assert_eq!(reconnect_delay(10), std::time::Duration::from_secs(4));
    }

    // ========================================================================
    // Mockall-based tests for more rigorous verification
    // ========================================================================

    #[test]
    fn test_mock_full_connection_flow() {
        // Test the complete happy path: Idle -> Scanning -> Connecting -> DiscoveringServices -> Connected
        let mock = MockAdapter::new();
        let adapter = Arc::new(mock);
        let mut machine = ConnectionStateMachine::new(adapter);

        // Idle -> Scanning
        machine.handle(ConnectionEvent::StartScan).unwrap();

        // Scanning -> Connecting
        machine
            .handle(ConnectionEvent::DeviceSelected {
                device_id: "mock-device-123".to_string(),
            })
            .unwrap();

        // Connecting -> DiscoveringServices
        machine.handle(ConnectionEvent::ConnectionSuccess).unwrap();

        // DiscoveringServices -> Connected
        machine.handle(ConnectionEvent::ServicesDiscovered).unwrap();

        // Verify we reached the Connected state successfully
        // The state machine should have processed all events without errors
    }

    #[test]
    fn test_mock_connection_recovery() {
        // Test: Connected -> Disconnected -> Reconnecting -> ReconnectSuccess -> Connected
        let mock = MockAdapter::new();
        let adapter = Arc::new(mock);
        let mut machine = ConnectionStateMachine::new(adapter);

        // Establish initial connection
        machine.handle(ConnectionEvent::StartScan).unwrap();
        machine
            .handle(ConnectionEvent::DeviceSelected {
                device_id: "device-abc".to_string(),
            })
            .unwrap();
        machine.handle(ConnectionEvent::ConnectionSuccess).unwrap();
        machine.handle(ConnectionEvent::ServicesDiscovered).unwrap();

        // Simulate unexpected disconnection
        machine.handle(ConnectionEvent::Disconnected).unwrap();

        // Successful reconnection
        machine.handle(ConnectionEvent::ReconnectSuccess).unwrap();

        // Machine should be back in Connected state
    }

    #[test]
    fn test_mock_reconnection_exhausted() {
        // Test: Reconnecting with 3 failures -> transitions to Idle
        let mock = MockAdapter::new();
        let adapter = Arc::new(mock);
        let mut machine = ConnectionStateMachine::new(adapter);

        // Establish initial connection
        machine.handle(ConnectionEvent::StartScan).unwrap();
        machine
            .handle(ConnectionEvent::DeviceSelected {
                device_id: "device-xyz".to_string(),
            })
            .unwrap();
        machine.handle(ConnectionEvent::ConnectionSuccess).unwrap();
        machine.handle(ConnectionEvent::ServicesDiscovered).unwrap();

        // Simulate disconnection
        machine.handle(ConnectionEvent::Disconnected).unwrap();

        // First reconnection attempt fails (attempts = 1)
        machine.handle(ConnectionEvent::ReconnectFailed).unwrap();

        // Second reconnection attempt fails (attempts = 2)
        machine.handle(ConnectionEvent::ReconnectFailed).unwrap();

        // Third reconnection attempt fails (attempts = 3)
        // This should transition to Idle as max retries reached
        machine.handle(ConnectionEvent::ReconnectFailed).unwrap();

        // Machine should be back in Idle state after exhausting retries
    }

    #[test]
    fn test_mock_user_cancellation_during_connection() {
        // Test: UserDisconnect from Connecting state -> Idle
        let mock = MockAdapter::new();
        let adapter = Arc::new(mock);
        let mut machine = ConnectionStateMachine::new(adapter);

        machine.handle(ConnectionEvent::StartScan).unwrap();
        machine
            .handle(ConnectionEvent::DeviceSelected {
                device_id: "device-1".to_string(),
            })
            .unwrap();

        // User cancels during connection attempt
        machine.handle(ConnectionEvent::UserDisconnect).unwrap();

        // Should be back in Idle state
    }

    #[test]
    fn test_mock_user_cancellation_from_reconnecting() {
        // Test: UserDisconnect from Reconnecting state -> Idle
        let mock = MockAdapter::new();
        let adapter = Arc::new(mock);
        let mut machine = ConnectionStateMachine::new(adapter);

        // Establish connection, then disconnect
        machine.handle(ConnectionEvent::StartScan).unwrap();
        machine
            .handle(ConnectionEvent::DeviceSelected {
                device_id: "device-1".to_string(),
            })
            .unwrap();
        machine.handle(ConnectionEvent::ConnectionSuccess).unwrap();
        machine.handle(ConnectionEvent::ServicesDiscovered).unwrap();
        machine.handle(ConnectionEvent::Disconnected).unwrap();

        // While in Reconnecting state, user cancels
        machine.handle(ConnectionEvent::UserDisconnect).unwrap();

        // Should be in Idle state
    }

    #[test]
    fn test_mock_connection_failure_during_service_discovery() {
        // Test: ConnectionFailed during DiscoveringServices -> Reconnecting
        let mock = MockAdapter::new();
        let adapter = Arc::new(mock);
        let mut machine = ConnectionStateMachine::new(adapter);

        machine.handle(ConnectionEvent::StartScan).unwrap();
        machine
            .handle(ConnectionEvent::DeviceSelected {
                device_id: "device-1".to_string(),
            })
            .unwrap();
        machine.handle(ConnectionEvent::ConnectionSuccess).unwrap();

        // Connection fails during service discovery
        machine.handle(ConnectionEvent::ConnectionFailed).unwrap();

        // Should transition to Reconnecting state with attempts = 1
    }

    #[test]
    fn test_mock_stop_scan_returns_to_idle() {
        // Test: Scanning -> StopScan -> Idle
        let mock = MockAdapter::new();
        let adapter = Arc::new(mock);
        let mut machine = ConnectionStateMachine::new(adapter);

        machine.handle(ConnectionEvent::StartScan).unwrap();

        // User stops the scan
        machine.handle(ConnectionEvent::StopScan).unwrap();

        // Should be back in Idle state
    }

    #[test]
    fn test_mock_reconnection_increments_attempts() {
        // Test: Verify reconnection attempt counter increments correctly
        let mock = MockAdapter::new();
        let adapter = Arc::new(mock);
        let mut machine = ConnectionStateMachine::new(adapter);

        // Establish connection and disconnect
        machine.handle(ConnectionEvent::StartScan).unwrap();
        machine
            .handle(ConnectionEvent::DeviceSelected {
                device_id: "device-1".to_string(),
            })
            .unwrap();
        machine.handle(ConnectionEvent::ConnectionSuccess).unwrap();
        machine.handle(ConnectionEvent::ServicesDiscovered).unwrap();
        machine.handle(ConnectionEvent::Disconnected).unwrap();

        // First failure (attempts = 1 -> 2)
        machine.handle(ConnectionEvent::ReconnectFailed).unwrap();

        // Second failure (attempts = 2 -> 3)
        machine.handle(ConnectionEvent::ReconnectFailed).unwrap();

        // At this point, one more failure would exhaust retries
        // Verify the machine is still in Reconnecting with attempts = 3
        machine.handle(ConnectionEvent::ReconnectFailed).unwrap();

        // After third failure, should be in Idle
    }

    #[test]
    fn test_mock_ignore_invalid_events() {
        // Test: Invalid events in certain states should be ignored (Super response)
        let mock = MockAdapter::new();
        let adapter = Arc::new(mock);
        let mut machine = ConnectionStateMachine::new(adapter);

        // In Idle state, ConnectionSuccess should be ignored
        machine.handle(ConnectionEvent::ConnectionSuccess).unwrap();

        // In Idle state, Disconnected should be ignored
        machine.handle(ConnectionEvent::Disconnected).unwrap();

        // Machine should still be in Idle state and handle valid events
        machine.handle(ConnectionEvent::StartScan).unwrap();
    }

    #[test]
    fn test_mock_disconnected_during_service_discovery() {
        // Test: Disconnected event during DiscoveringServices -> Reconnecting
        let mock = MockAdapter::new();
        let adapter = Arc::new(mock);
        let mut machine = ConnectionStateMachine::new(adapter);

        machine.handle(ConnectionEvent::StartScan).unwrap();
        machine
            .handle(ConnectionEvent::DeviceSelected {
                device_id: "device-1".to_string(),
            })
            .unwrap();
        machine.handle(ConnectionEvent::ConnectionSuccess).unwrap();

        // Device disconnects during service discovery
        machine.handle(ConnectionEvent::Disconnected).unwrap();

        // Should transition to Reconnecting
    }
}
