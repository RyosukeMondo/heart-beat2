# Tasks Document

## Phase 1: Critical Fixes - Disconnect API Implementation

Implement the disconnect() API function to allow programmatic device disconnection, replacing the current stub.

- [ ] 1. Design global connection state management
  - File: rust/src/api.rs
  - Define strategy for tracking active BLE connection globally
  - Consider using OnceCell/OnceLock or lazy_static for adapter reference
  - Plan cleanup of background tasks (HR stream, battery polling) on disconnect
  - Purpose: Enable clean disconnection without orphaned resources
  - _Leverage: rust/src/adapters/btleplug_adapter.rs (BtleplugAdapter)_
  - _Requirements: tech.md BLE reconnection requirement_
  - _Prompt: Role: Rust Systems Architect specializing in async resource management | Task: Design global state management strategy for tracking active BLE adapter connection, enabling clean disconnection | Restrictions: Must be thread-safe for tokio async context, avoid deadlocks, consider reconnection scenarios | Success: Clear design for connection state tracking, handles concurrent access safely, supports clean resource cleanup_

- [ ] 2. Implement connection state storage
  - File: rust/src/api.rs
  - Add static/global storage for active BtleplugAdapter instance
  - Store JoinHandle references for background tasks (HR stream, battery polling)
  - Implement accessor methods for setting/getting connection state
  - Purpose: Enable disconnect to access and clean up active connection
  - _Leverage: tokio::sync::Mutex or std::sync::OnceLock_
  - _Requirements: tech.md determinism principle_
  - _Prompt: Role: Rust Concurrency Developer | Task: Implement thread-safe global storage for active BLE connection state including adapter reference and task handles | Restrictions: Use appropriate sync primitives for async context, avoid blocking operations, ensure memory safety | Success: Connection state stored safely, accessible from disconnect function, no data races possible_

- [ ] 3. Implement disconnect() function
  - File: rust/src/api.rs
  - Replace stub with actual implementation
  - Abort background HR stream and battery polling tasks
  - Call BleAdapter::disconnect() on stored adapter
  - Clear connection state after successful disconnect
  - Purpose: Provide clean device disconnection for users
  - _Leverage: rust/src/ports/ble_adapter.rs (BleAdapter trait), task handles_
  - _Requirements: product.md session reliability_
  - _Prompt: Role: Rust Async Developer | Task: Implement disconnect() function that cleanly terminates background tasks and disconnects BLE adapter | Restrictions: Must handle case where already disconnected, avoid panics, emit appropriate connection status | Success: Disconnect terminates all background tasks, BLE adapter disconnected, state cleared, no resource leaks_

- [ ] 4. Update connect_device to store connection state
  - File: rust/src/api.rs
  - After successful connection, store adapter reference globally
  - Store spawned task JoinHandles for later cleanup
  - Ensure previous connection is disconnected before new connection
  - Purpose: Enable disconnect to access resources created during connect
  - _Leverage: existing connect_device implementation_
  - _Requirements: product.md single device connection model_
  - _Prompt: Role: Rust Developer | Task: Modify connect_device to store adapter and task handles in global state, enabling later disconnect | Restrictions: Must disconnect existing connection before new one, handle errors gracefully, maintain current functionality | Success: Connection state stored on successful connect, previous connections cleaned up, existing tests still pass_

- [ ] 5. Emit ConnectionStatus on disconnect
  - File: rust/src/api.rs
  - Emit ConnectionStatus::Disconnected when disconnect() called
  - Ensure UI receives notification of intentional disconnect
  - Distinguish user-initiated disconnect from connection loss
  - Purpose: Keep UI synchronized with connection state
  - _Leverage: rust/src/domain/reconnection.rs (ConnectionStatus enum)_
  - _Requirements: reconnection-handling spec_
  - _Prompt: Role: Event-Driven Systems Developer | Task: Emit appropriate ConnectionStatus event when disconnect() is called, enabling UI to reflect state change | Restrictions: Use existing ConnectionStatus enum, distinguish from connection loss, maintain event ordering | Success: UI receives disconnect notification, status banner updates correctly, no duplicate events_

- [ ] 6. Add disconnect unit tests
  - File: rust/src/api.rs (tests module)
  - Test disconnect when connected
  - Test disconnect when already disconnected (idempotent)
  - Test connect after disconnect (reconnection scenario)
  - Purpose: Ensure disconnect behaves correctly in all scenarios
  - _Leverage: rust/src/adapters/mock_adapter.rs_
  - _Requirements: product.md 80% test coverage_
  - _Prompt: Role: QA Engineer | Task: Create unit tests for disconnect() function covering connected, disconnected, and reconnection scenarios | Restrictions: Use mock adapter, tests must be deterministic, cover error cases | Success: Tests verify all disconnect scenarios, no resource leaks detected, reconnection works after disconnect_

- [ ] 7. Update Flutter UI for manual disconnect
  - File: lib/src/screens/session_screen.dart
  - Add disconnect button or menu option
  - Call disconnect API and handle response
  - Navigate appropriately after disconnect (back to home)
  - Purpose: Allow users to manually disconnect from device
  - _Leverage: lib/src/bridge/api_generated.dart/api.dart (disconnect function)_
  - _Requirements: UX completeness_
  - _Prompt: Role: Flutter Developer | Task: Add disconnect functionality to session screen UI, calling Rust disconnect API and handling navigation | Restrictions: Confirm before disconnect if session active, handle errors gracefully, follow Material Design patterns | Success: User can disconnect via UI, confirmation shown if needed, navigates to home after disconnect_
