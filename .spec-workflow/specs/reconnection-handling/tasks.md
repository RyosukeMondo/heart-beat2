# Tasks Document

- [x] 1.1 Add ReconnectionPolicy configuration
  - File: `rust/src/domain/reconnection.rs`
  - Define ReconnectionPolicy struct with max_attempts, delays
  - Add calculate_delay(attempt) method
  - Purpose: Configurable reconnection behavior
  - _Leverage: existing domain patterns_
  - _Requirements: 1_
  - _Prompt: Role: Rust domain developer | Task: Create rust/src/domain/reconnection.rs with ReconnectionPolicy struct. Fields: max_attempts (u8, default 5), initial_delay (Duration, default 1s), backoff_multiplier (f32, default 2.0), max_delay (Duration, default 16s). Add calculate_delay(attempt: u8) -> Duration using exponential backoff capped at max_delay. | Restrictions: Pure domain, no async | Success: Backoff calculation correct_

- [x] 1.2 Add ConnectionStatus enum
  - File: `rust/src/domain/reconnection.rs`
  - Define ConnectionStatus enum with all states
  - Derive Serialize for FRB
  - Purpose: Streamable connection state
  - _Leverage: existing state patterns_
  - _Requirements: 3_
  - _Prompt: Role: Rust developer | Task: Add ConnectionStatus enum to reconnection.rs. Variants: Disconnected, Connecting, Connected { device_id: String }, Reconnecting { attempt: u8, max_attempts: u8 }, ReconnectFailed { reason: String }. Derive Serialize. | Restrictions: FRB-compatible | Success: Enum compiles with serde_

- [x] 2.1 Extend ConnectivityStateMachine with reconnection tracking
  - File: `rust/src/state/connectivity.rs`
  - Add attempt_count and last_device_id to Reconnecting state
  - Implement attempt tracking and max attempts check
  - Purpose: State machine tracks reconnection
  - _Leverage: existing statig state machine_
  - _Requirements: 1_
  - _Prompt: Role: Rust state machine developer | Task: Modify Reconnecting state in connectivity.rs to include attempt_count: u8 and last_device_id: String. On entry to Reconnecting, set attempt_count = 1. On Reconnect event, increment attempt_count. If > max_attempts, transition to Disconnected. | Restrictions: Use statig patterns | Success: Attempts tracked correctly_

- [x] 2.2 Add reconnection loop to BtleplugAdapter
  - File: `rust/src/adapters/btleplug_adapter.rs`
  - Implement reconnect() method with exponential backoff
  - Emit ConnectionStatus updates
  - Purpose: Actual reconnection attempts
  - _Leverage: existing connect logic, ReconnectionPolicy_
  - _Requirements: 1_
  - _Prompt: Role: Rust async developer | Task: Add async fn reconnect(&self, device_id: &str, policy: &ReconnectionPolicy, status_tx: Sender<ConnectionStatus>) method. Loop: emit Reconnecting status, delay using policy.calculate_delay(attempt), call connect_to_device, on success emit Connected and return, on failure increment attempt. After max_attempts emit ReconnectFailed. | Restrictions: Cancellable via CancellationToken | Success: Reconnection with backoff works_

- [ ] 3.1 Add connection status stream to api.rs
  - File: `rust/src/api.rs`
  - Add create_connection_status_stream()
  - Wire to adapter connection events
  - Purpose: Stream status to Flutter
  - _Leverage: existing stream patterns_
  - _Requirements: 3_
  - _Prompt: Role: Rust FFI developer | Task: Add pub async fn create_connection_status_stream() -> StreamSink<ConnectionStatus>. Create broadcast channel, wire to BtleplugAdapter connection events. Emit status changes: Connected on connect, Reconnecting during reconnect attempts, ReconnectFailed on max attempts. | Restrictions: FRB-compatible | Success: Flutter receives connection status_

- [ ] 3.2 Add reconnection UI banner
  - File: `lib/src/widgets/connection_banner.dart`
  - Display connection status as top banner
  - Show attempt count during reconnection
  - Offer retry button on failure
  - Purpose: User feedback
  - _Leverage: Material Banner widget_
  - _Requirements: 3_
  - _Prompt: Role: Flutter developer | Task: Create ConnectionBanner widget subscribing to connection status stream. When Reconnecting, show MaterialBanner with "Reconnecting... (attempt X/5)" and spinner. When ReconnectFailed, show "Connection lost" with Retry button. When Connected, hide banner (or show brief success). | Restrictions: Non-intrusive positioning | Success: Status clearly visible_

- [ ] 4.1 Integrate reconnection with SessionExecutor
  - File: `rust/src/scheduler/executor.rs`
  - Pause session on disconnect
  - Resume session on successful reconnect
  - Purpose: Session preservation
  - _Leverage: existing pause/resume_
  - _Requirements: 2_
  - _Prompt: Role: Rust integration developer | Task: Modify SessionExecutor to observe connection status. On ConnectionStatus::Disconnected or Reconnecting, call pause_session() if in progress. On ConnectionStatus::Connected, call resume_session() if was paused for reconnection. Track reason_for_pause to distinguish user pause vs reconnect pause. | Restrictions: Don't resume if user paused | Success: Session preserves progress_

- [ ] 4.2 Add connection banner to screens
  - File: `lib/src/screens/session_screen.dart`, `workout_screen.dart`
  - Add ConnectionBanner at top of screens
  - Purpose: Show status during sessions
  - _Leverage: ConnectionBanner widget_
  - _Requirements: 3_
  - _Prompt: Role: Flutter developer | Task: Add ConnectionBanner widget to session_screen.dart and workout_screen.dart. Place at top of screen body using Column with banner first. Ensure banner shows/hides based on connection state. | Restrictions: Don't obstruct critical UI | Success: Reconnection visible during workout_

- [ ] 5.1 Add reconnection unit tests
  - File: `rust/src/domain/reconnection.rs` (tests module)
  - Test backoff calculation
  - Test attempt counting
  - Purpose: Validate reconnection logic
  - _Leverage: existing test patterns_
  - _Requirements: 1_
  - _Prompt: Role: Rust test developer | Task: Add tests module to reconnection.rs. Test calculate_delay: attempt 1 = 1s, attempt 2 = 2s, attempt 3 = 4s, capped at max_delay. Test ConnectionStatus serialization. | Restrictions: No async in unit tests | Success: Backoff tests pass_

- [ ] 5.2 Test reconnection on device
  - File: N/A (manual testing)
  - Test by moving device out of range
  - Verify reconnection attempts and UI feedback
  - Verify session pauses and resumes
  - Purpose: End-to-end validation
  - _Leverage: real Coospo HW9 device_
  - _Requirements: 1, 2, 3, 4_
  - _Prompt: Role: QA Engineer | Task: Build and install APK. Connect to HR monitor, start workout. Move device far away (>10m) to trigger disconnect. Verify: banner shows reconnecting with attempt count, session pauses, returning to range triggers reconnect, session resumes. Test failure case by keeping device away. | Restrictions: Test on real device | Success: Reconnection flow works_
