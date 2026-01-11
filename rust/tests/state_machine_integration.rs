//! Integration tests for the connection state machine with mock adapter.
//!
//! This module tests the full connection lifecycle using the MockAdapter to simulate
//! realistic scenarios. Unlike unit tests that mock individual methods, these tests
//! exercise the complete interaction between the state machine and a real (simulated)
//! BLE adapter implementation.

use heart_beat::adapters::mock_adapter::{MockAdapter, MockConfig};
use heart_beat::domain::heart_rate::parse_heart_rate;
use heart_beat::ports::ble_adapter::BleAdapter;
use heart_beat::state::connectivity::{reconnect_delay, ConnectionEvent, ConnectionStateMachine};
use std::sync::Arc;
use tokio::time::{timeout, Duration};

/// Test the complete happy path: scan -> discover -> connect -> stream data -> disconnect
///
/// This test simulates a typical user workflow:
/// 1. Start scanning for devices
/// 2. Select a discovered device
/// 3. Establish connection
/// 4. Discover services
/// 5. Stream heart rate data
/// 6. User disconnects
#[tokio::test]
async fn test_full_connection_lifecycle() {
    // Set up tracing for debug output
    let _ = tracing_subscriber::fmt().with_test_writer().try_init();

    // Create mock adapter with faster update rate for testing
    let config = MockConfig {
        baseline_bpm: 75,
        update_rate: 5.0, // 5 Hz for faster testing
        ..Default::default()
    };
    let adapter = Arc::new(MockAdapter::with_config(config));

    // Create state machine
    let mut state_machine = ConnectionStateMachine::new(adapter.clone());

    // Step 1: Start scanning
    state_machine
        .handle(ConnectionEvent::StartScan)
        .expect("StartScan should succeed");

    // Simulate scan operation
    adapter
        .start_scan()
        .await
        .expect("start_scan should succeed");

    tokio::time::sleep(Duration::from_millis(100)).await; // Give scan time to complete

    // Get discovered devices
    let devices = adapter.get_discovered_devices().await;
    assert!(!devices.is_empty(), "Should discover at least one device");

    let device_id = devices[0].id.clone();

    // Step 2: Select device and connect
    state_machine
        .handle(ConnectionEvent::DeviceSelected {
            device_id: device_id.clone(),
        })
        .expect("DeviceSelected should succeed");

    // Perform actual connection
    adapter
        .connect(&device_id)
        .await
        .expect("connect should succeed");

    state_machine
        .handle(ConnectionEvent::ConnectionSuccess)
        .expect("ConnectionSuccess should succeed");

    // Step 3: Discover services
    state_machine
        .handle(ConnectionEvent::ServicesDiscovered)
        .expect("ServicesDiscovered should succeed");

    // Step 4: Subscribe to HR notifications and stream data
    let mut hr_receiver = adapter
        .subscribe_hr()
        .await
        .expect("subscribe_hr should succeed");

    // Receive and parse several HR packets
    let mut successful_parses = 0;
    for i in 0..5 {
        let packet = timeout(Duration::from_secs(2), hr_receiver.recv())
            .await
            .expect("Should receive packet within timeout")
            .expect("Should receive valid packet");

        tracing::debug!("Received packet {}: {:?}", i, packet);

        let measurement = parse_heart_rate(&packet).expect("Should parse HR packet");

        tracing::info!(
            "Parsed HR: {} BPM, RR intervals: {:?}",
            measurement.bpm,
            measurement.rr_intervals
        );

        assert!(
            measurement.bpm >= 30 && measurement.bpm <= 220,
            "BPM should be in valid physiological range"
        );
        assert!(
            !measurement.rr_intervals.is_empty(),
            "Should have RR intervals"
        );

        successful_parses += 1;
    }

    assert_eq!(
        successful_parses, 5,
        "Should successfully parse all 5 packets"
    );

    // Step 5: User disconnects
    state_machine
        .handle(ConnectionEvent::UserDisconnect)
        .expect("UserDisconnect should succeed");

    adapter
        .disconnect()
        .await
        .expect("disconnect should succeed");

    tracing::info!("Full connection lifecycle test completed successfully");
}

/// Test reconnection scenario: connection loss followed by successful recovery
///
/// This test simulates:
/// 1. Establish a connection
/// 2. Connection is lost unexpectedly
/// 3. State machine enters reconnecting state
/// 4. Reconnection succeeds after appropriate delay
/// 5. Continue streaming data
#[tokio::test]
async fn test_reconnection_success() {
    let _ = tracing_subscriber::fmt().with_test_writer().try_init();

    let config = MockConfig {
        baseline_bpm: 80,
        update_rate: 5.0,
        ..Default::default()
    };
    let adapter = Arc::new(MockAdapter::with_config(config));
    let mut state_machine = ConnectionStateMachine::new(adapter.clone());

    // Step 1: Establish initial connection
    state_machine
        .handle(ConnectionEvent::StartScan)
        .expect("StartScan should succeed");

    adapter
        .start_scan()
        .await
        .expect("start_scan should succeed");
    let devices = adapter.get_discovered_devices().await;
    let device_id = devices[0].id.clone();

    state_machine
        .handle(ConnectionEvent::DeviceSelected {
            device_id: device_id.clone(),
        })
        .expect("DeviceSelected should succeed");

    adapter
        .connect(&device_id)
        .await
        .expect("connect should succeed");

    state_machine
        .handle(ConnectionEvent::ConnectionSuccess)
        .expect("ConnectionSuccess should succeed");

    state_machine
        .handle(ConnectionEvent::ServicesDiscovered)
        .expect("ServicesDiscovered should succeed");

    // Step 2: Start streaming
    let mut hr_receiver = adapter
        .subscribe_hr()
        .await
        .expect("subscribe should succeed");

    // Verify initial data stream
    let packet = timeout(Duration::from_secs(1), hr_receiver.recv())
        .await
        .expect("Should receive initial packet")
        .expect("Should have valid packet");

    parse_heart_rate(&packet).expect("Should parse initial packet");

    // Step 3: Simulate unexpected disconnection
    tracing::info!("Simulating unexpected disconnection...");
    adapter
        .disconnect()
        .await
        .expect("disconnect should succeed");

    state_machine
        .handle(ConnectionEvent::Disconnected)
        .expect("Disconnected event should succeed");

    // Step 4: Enter reconnecting state and wait with exponential backoff
    tracing::info!("Waiting for reconnection delay (1 second)...");
    let delay = reconnect_delay(1);
    assert_eq!(
        delay,
        Duration::from_secs(1),
        "First attempt should have 1s delay"
    );
    tokio::time::sleep(delay).await;

    // Step 5: Simulate successful reconnection
    adapter
        .connect(&device_id)
        .await
        .expect("reconnect should succeed");

    state_machine
        .handle(ConnectionEvent::ReconnectSuccess)
        .expect("ReconnectSuccess should succeed");

    // Step 6: Resume streaming
    let mut hr_receiver = adapter
        .subscribe_hr()
        .await
        .expect("subscribe should succeed");

    // Verify data stream resumed
    let packet = timeout(Duration::from_secs(1), hr_receiver.recv())
        .await
        .expect("Should receive packet after reconnection")
        .expect("Should have valid packet");

    parse_heart_rate(&packet).expect("Should parse packet after reconnection");

    tracing::info!("Reconnection test completed successfully");
}

/// Test reconnection failure scenario: multiple failed attempts leading to giving up
///
/// This test simulates:
/// 1. Establish a connection
/// 2. Connection is lost
/// 3. Three reconnection attempts fail (with exponential backoff)
/// 4. State machine gives up and returns to Idle
#[tokio::test]
async fn test_reconnection_exhausted() {
    let _ = tracing_subscriber::fmt().with_test_writer().try_init();

    let adapter = Arc::new(MockAdapter::new());
    let mut state_machine = ConnectionStateMachine::new(adapter.clone());

    // Step 1: Establish connection
    state_machine
        .handle(ConnectionEvent::StartScan)
        .expect("StartScan should succeed");

    adapter
        .start_scan()
        .await
        .expect("start_scan should succeed");
    let devices = adapter.get_discovered_devices().await;
    let device_id = devices[0].id.clone();

    state_machine
        .handle(ConnectionEvent::DeviceSelected {
            device_id: device_id.clone(),
        })
        .expect("DeviceSelected should succeed");

    adapter
        .connect(&device_id)
        .await
        .expect("connect should succeed");

    state_machine
        .handle(ConnectionEvent::ConnectionSuccess)
        .expect("ConnectionSuccess should succeed");

    state_machine
        .handle(ConnectionEvent::ServicesDiscovered)
        .expect("ServicesDiscovered should succeed");

    // Step 2: Disconnect
    adapter
        .disconnect()
        .await
        .expect("disconnect should succeed");

    state_machine
        .handle(ConnectionEvent::Disconnected)
        .expect("Disconnected should succeed");

    // Step 3: Simulate 3 failed reconnection attempts with proper delays
    tracing::info!("Simulating first reconnection attempt failure...");
    let delay1 = reconnect_delay(1);
    assert_eq!(delay1, Duration::from_secs(1));
    tokio::time::sleep(delay1).await;
    state_machine
        .handle(ConnectionEvent::ReconnectFailed)
        .expect("First ReconnectFailed should succeed");

    tracing::info!("Simulating second reconnection attempt failure...");
    let delay2 = reconnect_delay(2);
    assert_eq!(delay2, Duration::from_secs(2));
    tokio::time::sleep(delay2).await;
    state_machine
        .handle(ConnectionEvent::ReconnectFailed)
        .expect("Second ReconnectFailed should succeed");

    tracing::info!("Simulating third reconnection attempt failure...");
    let delay3 = reconnect_delay(3);
    assert_eq!(delay3, Duration::from_secs(4));
    tokio::time::sleep(delay3).await;
    state_machine
        .handle(ConnectionEvent::ReconnectFailed)
        .expect("Third ReconnectFailed should succeed");

    tracing::info!("Reconnection exhausted, state machine should return to Idle");

    // The state machine should now be in Idle state after exhausting retries
    // We can verify this by attempting to start a new scan
    state_machine
        .handle(ConnectionEvent::StartScan)
        .expect("Should be able to start scan from Idle");

    tracing::info!("Reconnection exhaustion test completed successfully");
}

/// Test that the state machine handles rapid state transitions correctly
///
/// This test verifies:
/// 1. Multiple rapid event transitions
/// 2. State machine consistency under load
/// 3. No race conditions or panics
#[tokio::test]
async fn test_rapid_state_transitions() {
    let _ = tracing_subscriber::fmt().with_test_writer().try_init();

    let adapter = Arc::new(MockAdapter::new());
    let mut state_machine = ConnectionStateMachine::new(adapter.clone());

    // Rapid scan start/stop cycles
    for i in 0..10 {
        tracing::debug!("Scan cycle {}", i);
        state_machine
            .handle(ConnectionEvent::StartScan)
            .expect("StartScan should succeed");
        state_machine
            .handle(ConnectionEvent::StopScan)
            .expect("StopScan should succeed");
    }

    // Rapid connection attempts
    adapter
        .start_scan()
        .await
        .expect("start_scan should succeed");
    let devices = adapter.get_discovered_devices().await;
    let device_id = devices[0].id.clone();

    state_machine
        .handle(ConnectionEvent::StartScan)
        .expect("StartScan should succeed");

    for i in 0..5 {
        tracing::debug!("Connection cycle {}", i);
        state_machine
            .handle(ConnectionEvent::DeviceSelected {
                device_id: device_id.clone(),
            })
            .expect("DeviceSelected should succeed");

        state_machine
            .handle(ConnectionEvent::UserDisconnect)
            .expect("UserDisconnect should succeed");
    }

    tracing::info!("Rapid state transition test completed successfully");
}

/// Test user cancellation during various connection states
///
/// This verifies that UserDisconnect is properly handled from:
/// - Scanning state
/// - Connecting state
/// - DiscoveringServices state
/// - Connected state
/// - Reconnecting state
#[tokio::test]
async fn test_user_cancellation_scenarios() {
    let _ = tracing_subscriber::fmt().with_test_writer().try_init();

    // Test 1: Cancel during scanning
    {
        let adapter = Arc::new(MockAdapter::new());
        let mut sm = ConnectionStateMachine::new(adapter.clone());

        sm.handle(ConnectionEvent::StartScan)
            .expect("StartScan should succeed");
        sm.handle(ConnectionEvent::UserDisconnect)
            .expect("UserDisconnect from Scanning should succeed");
    }

    // Test 2: Cancel during connecting
    {
        let adapter = Arc::new(MockAdapter::new());
        let mut sm = ConnectionStateMachine::new(adapter.clone());

        adapter
            .start_scan()
            .await
            .expect("start_scan should succeed");
        let devices = adapter.get_discovered_devices().await;
        let device_id = devices[0].id.clone();

        sm.handle(ConnectionEvent::StartScan)
            .expect("StartScan should succeed");
        sm.handle(ConnectionEvent::DeviceSelected {
            device_id: device_id.clone(),
        })
        .expect("DeviceSelected should succeed");
        sm.handle(ConnectionEvent::UserDisconnect)
            .expect("UserDisconnect from Connecting should succeed");
    }

    // Test 3: Cancel during service discovery
    {
        let adapter = Arc::new(MockAdapter::new());
        let mut sm = ConnectionStateMachine::new(adapter.clone());

        adapter
            .start_scan()
            .await
            .expect("start_scan should succeed");
        let devices = adapter.get_discovered_devices().await;
        let device_id = devices[0].id.clone();

        sm.handle(ConnectionEvent::StartScan)
            .expect("StartScan should succeed");
        sm.handle(ConnectionEvent::DeviceSelected {
            device_id: device_id.clone(),
        })
        .expect("DeviceSelected should succeed");
        adapter
            .connect(&device_id)
            .await
            .expect("connect should succeed");
        sm.handle(ConnectionEvent::ConnectionSuccess)
            .expect("ConnectionSuccess should succeed");
        sm.handle(ConnectionEvent::UserDisconnect)
            .expect("UserDisconnect from DiscoveringServices should succeed");
    }

    // Test 4: Cancel from connected state
    {
        let adapter = Arc::new(MockAdapter::new());
        let mut sm = ConnectionStateMachine::new(adapter.clone());

        adapter
            .start_scan()
            .await
            .expect("start_scan should succeed");
        let devices = adapter.get_discovered_devices().await;
        let device_id = devices[0].id.clone();

        sm.handle(ConnectionEvent::StartScan)
            .expect("StartScan should succeed");
        sm.handle(ConnectionEvent::DeviceSelected {
            device_id: device_id.clone(),
        })
        .expect("DeviceSelected should succeed");
        adapter
            .connect(&device_id)
            .await
            .expect("connect should succeed");
        sm.handle(ConnectionEvent::ConnectionSuccess)
            .expect("ConnectionSuccess should succeed");
        sm.handle(ConnectionEvent::ServicesDiscovered)
            .expect("ServicesDiscovered should succeed");
        sm.handle(ConnectionEvent::UserDisconnect)
            .expect("UserDisconnect from Connected should succeed");
    }

    // Test 5: Cancel during reconnection
    {
        let adapter = Arc::new(MockAdapter::new());
        let mut sm = ConnectionStateMachine::new(adapter.clone());

        adapter
            .start_scan()
            .await
            .expect("start_scan should succeed");
        let devices = adapter.get_discovered_devices().await;
        let device_id = devices[0].id.clone();

        sm.handle(ConnectionEvent::StartScan)
            .expect("StartScan should succeed");
        sm.handle(ConnectionEvent::DeviceSelected {
            device_id: device_id.clone(),
        })
        .expect("DeviceSelected should succeed");
        adapter
            .connect(&device_id)
            .await
            .expect("connect should succeed");
        sm.handle(ConnectionEvent::ConnectionSuccess)
            .expect("ConnectionSuccess should succeed");
        sm.handle(ConnectionEvent::ServicesDiscovered)
            .expect("ServicesDiscovered should succeed");
        sm.handle(ConnectionEvent::Disconnected)
            .expect("Disconnected should succeed");
        sm.handle(ConnectionEvent::UserDisconnect)
            .expect("UserDisconnect from Reconnecting should succeed");
    }

    tracing::info!("User cancellation scenarios test completed successfully");
}

/// Test connection failure during service discovery triggers reconnection
///
/// This simulates a scenario where the connection is established but fails
/// during service discovery, which should trigger the reconnection logic.
#[tokio::test]
async fn test_connection_failure_during_service_discovery() {
    let _ = tracing_subscriber::fmt().with_test_writer().try_init();

    let adapter = Arc::new(MockAdapter::new());
    let mut state_machine = ConnectionStateMachine::new(adapter.clone());

    // Establish connection
    adapter
        .start_scan()
        .await
        .expect("start_scan should succeed");
    let devices = adapter.get_discovered_devices().await;
    let device_id = devices[0].id.clone();

    state_machine
        .handle(ConnectionEvent::StartScan)
        .expect("StartScan should succeed");
    state_machine
        .handle(ConnectionEvent::DeviceSelected {
            device_id: device_id.clone(),
        })
        .expect("DeviceSelected should succeed");

    adapter
        .connect(&device_id)
        .await
        .expect("connect should succeed");

    state_machine
        .handle(ConnectionEvent::ConnectionSuccess)
        .expect("ConnectionSuccess should succeed");

    // Simulate connection failure during service discovery
    adapter
        .disconnect()
        .await
        .expect("disconnect should succeed");

    state_machine
        .handle(ConnectionEvent::ConnectionFailed)
        .expect("ConnectionFailed during service discovery should succeed");

    // State machine should now be in Reconnecting state (attempt 1)
    // Simulate successful reconnection
    tokio::time::sleep(reconnect_delay(1)).await;
    adapter
        .connect(&device_id)
        .await
        .expect("reconnect should succeed");

    state_machine
        .handle(ConnectionEvent::ReconnectSuccess)
        .expect("ReconnectSuccess should succeed");

    tracing::info!("Service discovery failure test completed successfully");
}
