# Tasks Document

## Phase 1: Project Setup & Domain Types

- [x] 1.1 Initialize Rust project with Cargo.toml
  - File: `rust/Cargo.toml`
  - Create Rust project with all required dependencies (tokio, btleplug, statig, etc.)
  - Configure binary target for CLI
  - Purpose: Establish project foundation with correct dependency versions
  - _Leverage: tech.md dependency table_
  - _Requirements: All_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Developer specializing in project setup | Task: Create Cargo.toml with all dependencies from tech.md including tokio, flutter_rust_bridge, btleplug, cardio-rs, kalman_filters, statig, tokio-cron-scheduler, tracing, anyhow, serde, uuid, and dev-dependencies mockall and proptest. Configure [[bin]] target for cli | Restrictions: Use exact versions from tech.md, do not add unnecessary dependencies | Success: cargo check passes, all dependencies resolve correctly | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

- [x] 1.2 Create domain types in heart_rate.rs
  - File: `rust/src/domain/heart_rate.rs`
  - Define HeartRateMeasurement struct and Zone enum
  - Implement Display traits for logging
  - Purpose: Establish core data types for heart rate handling
  - _Leverage: design.md data models_
  - _Requirements: 3, 4_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Developer specializing in type systems | Task: Create HeartRateMeasurement struct with bpm (u16), rr_intervals (Vec<u16>), sensor_contact (bool). Create Zone enum (Zone1-Zone5). Implement Display for logging. Add doc comments | Restrictions: No I/O dependencies, pure data types only, follow structure.md naming conventions | Success: Types compile, Display outputs readable format | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

- [x] 1.3 Create FilteredHeartRate and DiscoveredDevice types
  - File: `rust/src/domain/heart_rate.rs` (extend)
  - Add FilteredHeartRate struct for processed output
  - Add DiscoveredDevice struct for scan results
  - Purpose: Complete domain type definitions
  - _Leverage: design.md data models_
  - _Requirements: 1, 3, 4_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Developer | Task: Add FilteredHeartRate struct (raw_bpm, filtered_bpm, rmssd Option, battery_level Option, timestamp). Add DiscoveredDevice struct (id String, name Option, rssi i16). Derive Serialize for FRB compatibility | Restrictions: Keep in same file, maintain consistency with existing types | Success: All types compile with serde derives | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

## Phase 2: BLE Packet Parsing

- [x] 2.1 Implement HR packet parser
  - File: `rust/src/domain/heart_rate.rs` (extend)
  - Implement parse_heart_rate function per Bluetooth SIG spec
  - Handle both UINT8 and UINT16 BPM formats
  - Extract RR-intervals when present
  - Purpose: Parse raw BLE packets into domain types
  - _Leverage: research.md packet format section_
  - _Requirements: 3_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Developer with BLE protocol expertise | Task: Implement parse_heart_rate(data: &[u8]) -> Result<HeartRateMeasurement>. Parse flags byte for format detection. Handle UINT8/UINT16 BPM. Extract sensor contact status. Parse RR-intervals (little-endian u16, 1/1024s resolution) when bit 4 set | Restrictions: Return Result not panic, validate array bounds, use anyhow for errors | Success: Parses valid packets correctly, returns Err for invalid data | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

- [x] 2.2 Add proptest for parser robustness
  - File: `rust/src/domain/heart_rate.rs` (tests module)
  - Create property-based tests for parser
  - Ensure no panics on arbitrary input
  - Purpose: Guarantee parser safety with random inputs
  - _Leverage: proptest crate_
  - _Requirements: 3, Non-functional (Reliability)_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: QA Engineer with Rust testing expertise | Task: Add #[cfg(test)] module with proptest tests. Property: parse_heart_rate never panics on any &[u8]. Property: valid packets with correct flags parse successfully. Use proptest::arbitrary for byte vectors | Restrictions: Tests in same file, use proptest not quickcheck | Success: cargo test passes, proptest runs 256+ cases | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

## Phase 3: Signal Processing

- [x] 3.1 Implement Kalman filter wrapper
  - File: `rust/src/domain/filters.rs`
  - Create KalmanFilter struct wrapping kalman_filters crate
  - Configure for heart rate tracking (appropriate noise parameters)
  - Purpose: Provide noise-reduced BPM values
  - _Leverage: kalman_filters crate, design.md Component 2_
  - _Requirements: 4_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Developer with DSP knowledge | Task: Create KalmanFilter struct with new(process_noise, measurement_noise) and update(measurement) -> f64. Wrap kalman_filters::Kalman1D. Default parameters: process_noise=0.1, measurement_noise=2.0 for HR tracking | Restrictions: Stateful struct, not pure function. Document parameter choices | Success: Filter smooths noisy input, tracks step changes | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

- [x] 3.2 Implement HRV calculator
  - File: `rust/src/domain/hrv.rs`
  - Implement RMSSD calculation from RR-intervals
  - Add validation for physiologically valid intervals
  - Purpose: Provide HRV metrics for stress/recovery indication
  - _Leverage: cardio-rs crate, design.md Component 3_
  - _Requirements: 4_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Developer with biomedical signal processing knowledge | Task: Implement calculate_rmssd(rr_intervals: &[u16]) -> Option<f64>. Convert 1/1024s units to ms. Use cardio-rs or implement RMSSD formula. Return None if < 2 intervals. Reject intervals outside 300-2000ms range | Restrictions: Pure function, no side effects | Success: Matches cardio-rs reference values for known inputs | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

- [x] 3.3 Add anomaly detection
  - File: `rust/src/domain/filters.rs` (extend)
  - Add is_valid_bpm function rejecting physiologically impossible values
  - Purpose: Reject sensor artifacts before filtering
  - _Leverage: design.md error handling_
  - _Requirements: 4_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Developer | Task: Add is_valid_bpm(bpm: u16) -> bool returning true for 30-220 range. Add filter_if_valid method to KalmanFilter that skips invalid values | Restrictions: Simple threshold check, no ML | Success: Values outside 30-220 rejected, filter state preserved | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

## Phase 4: BLE Adapter Port & Implementation

- [x] 4.1 Define BleAdapter trait
  - File: `rust/src/ports/ble_adapter.rs`
  - Define async trait for BLE operations
  - Include scan, connect, disconnect, subscribe methods
  - Purpose: Abstract BLE for testability and swappability
  - _Leverage: design.md Component 4, async_trait crate_
  - _Requirements: 1, 2, 3, 5_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Architect specializing in trait design | Task: Create BleAdapter trait with async_trait. Methods: start_scan, stop_scan, get_discovered_devices, connect(device_id), disconnect, subscribe_hr() -> Receiver<Vec<u8>>, read_battery() -> u8. All return Result<T> | Restrictions: Trait only, no implementation. Use tokio::sync::mpsc::Receiver | Success: Trait compiles, methods cover all BLE operations | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

- [x] 4.2 Implement btleplug adapter
  - File: `rust/src/adapters/btleplug_adapter.rs`
  - Implement BleAdapter trait using btleplug
  - Handle Linux BlueZ backend
  - Purpose: Real BLE communication for production and CLI debugging
  - _Leverage: btleplug crate, design.md Component 5_
  - _Requirements: 1, 2, 3, 5_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Developer with btleplug experience | Task: Create BtleplugAdapter implementing BleAdapter. Use btleplug::platform::Manager. Filter devices by HR Service UUID 0x180D. Subscribe to characteristic 0x2A37. Forward notifications via mpsc channel | Restrictions: Handle btleplug errors gracefully, convert to anyhow::Error | Success: Can scan and connect to real Coospo HW9 on Linux | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

- [x] 4.3 Implement mock adapter
  - File: `rust/src/adapters/mock_adapter.rs`
  - Implement BleAdapter with simulated data
  - Generate realistic HR patterns for testing
  - Purpose: Enable testing without hardware
  - _Leverage: design.md Component 6_
  - _Requirements: 7_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Developer | Task: Create MockAdapter implementing BleAdapter. Simulate device discovery with fake device. Generate HR data: baseline 70 BPM with ±5 noise, occasional spikes. Include RR-intervals. Configurable via MockConfig | Restrictions: Use tokio::time for pacing, realistic 1Hz update rate | Success: Streams realistic mock data, supports testing without hardware | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

## Phase 5: Connection State Machine

- [x] 5.1 Define state machine with statig
  - File: `rust/src/state/connectivity.rs`
  - Define ConnectionState enum and events
  - Implement state transitions using statig
  - Purpose: Manage BLE connection lifecycle formally
  - _Leverage: statig crate, design.md Component 7_
  - _Requirements: 6_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Developer with state machine expertise | Task: Create ConnectionStateMachine using statig. States: Idle, Scanning, Connecting, DiscoveringServices, Connected, Reconnecting. Events: StartScan, DeviceSelected, ConnectionSuccess, ConnectionFailed, Disconnected. Implement transition logic | Restrictions: Use statig::blocking, follow HSM patterns | Success: All state transitions compile and match requirements.md R6 | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

- [x] 5.2 Add reconnection logic
  - File: `rust/src/state/connectivity.rs` (extend)
  - Implement exponential backoff for reconnection
  - Track attempt count, max 3 retries
  - Purpose: Handle transient disconnections gracefully
  - _Leverage: design.md error handling_
  - _Requirements: 2, 6_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Developer | Task: Add Reconnecting state with attempts counter. Implement exponential backoff (1s, 2s, 4s). Transition to Idle after 3 failed attempts. Add reconnect_delay() helper | Restrictions: Use tokio::time::sleep for delays | Success: Reconnection attempts spaced correctly, gives up after 3 tries | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

- [x] 5.3 Add state machine unit tests
  - File: `rust/src/state/connectivity.rs` (tests module)
  - Test all state transitions
  - Use mockall to mock BleAdapter
  - Purpose: Verify state machine correctness
  - _Leverage: mockall crate_
  - _Requirements: 6_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: QA Engineer | Task: Create #[cfg(test)] module. Mock BleAdapter with mockall. Test: Idle->Scanning->Connecting->Connected flow. Test: Connected->Reconnecting->Connected recovery. Test: Reconnecting->Idle after 3 failures | Restrictions: Mock all I/O, test state logic only | Success: All transition paths tested, edge cases covered | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

## Phase 6: CLI Implementation

- [x] 6.1 Create CLI binary structure
  - File: `rust/src/bin/cli.rs`
  - Set up clap for argument parsing
  - Define subcommands: scan, connect, mock
  - Purpose: Entry point for CLI debugging tool
  - _Leverage: clap crate, tech.md CLI strategy_
  - _Requirements: 7_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Developer with CLI expertise | Task: Create cli.rs with clap derive macros. Subcommands: scan (list devices), connect <device-id> (stream HR), mock (simulate). Add --verbose flag for debug logging. Initialize tracing subscriber | Restrictions: Use clap derive, not builder pattern | Success: cli --help shows all commands, arguments parse correctly | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

- [x] 6.2 Implement scan command
  - File: `rust/src/bin/cli.rs` (extend)
  - Use BtleplugAdapter to scan for devices
  - Display discovered devices with RSSI
  - Purpose: Device discovery via CLI
  - _Leverage: BtleplugAdapter_
  - _Requirements: 1, 7_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Developer | Task: Implement scan subcommand. Create BtleplugAdapter, call start_scan, wait 5 seconds, call stop_scan. Print each device: name, id, rssi. Format as table | Restrictions: Timeout after 10 seconds, handle no devices found | Success: Lists Coospo HW9 when nearby, shows "No devices found" otherwise | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

- [x] 6.3 Implement connect command
  - File: `rust/src/bin/cli.rs` (extend)
  - Connect to device, stream filtered HR to stdout
  - Display raw BPM, filtered BPM, and state transitions
  - Purpose: Real-time HR monitoring via CLI
  - _Leverage: BtleplugAdapter, KalmanFilter, ConnectionStateMachine_
  - _Requirements: 2, 3, 4, 7_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Developer | Task: Implement connect subcommand. Create state machine, connect to device. On HR notification: parse, filter, print. Format: timestamp, raw_bpm, filtered_bpm, rmssd (if available). Ctrl+C to disconnect | Restrictions: Clean disconnect on exit, handle connection loss | Success: Streams HR data in real-time, recovers from brief disconnections | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

- [x] 6.4 Implement mock command
  - File: `rust/src/bin/cli.rs` (extend)
  - Use MockAdapter to stream simulated data
  - Purpose: Test pipeline without hardware
  - _Leverage: MockAdapter_
  - _Requirements: 7_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Developer | Task: Implement mock subcommand. Use MockAdapter instead of BtleplugAdapter. Same output format as connect. Add --duration flag for timed runs | Restrictions: Reuse connect logic, only swap adapter | Success: Streams mock HR data, useful for development without hardware | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

## Phase 7: Module Organization

- [x] 7.1 Create module structure with mod.rs files
  - Files: `rust/src/lib.rs`, `rust/src/domain/mod.rs`, `rust/src/ports/mod.rs`, `rust/src/adapters/mod.rs`, `rust/src/state/mod.rs`
  - Re-export public items
  - Purpose: Organize crate structure per structure.md
  - _Leverage: structure.md directory organization_
  - _Requirements: Non-functional (Code Architecture)_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust Developer | Task: Create mod.rs for each directory. lib.rs re-exports domain, ports, adapters, state. Each mod.rs declares submodules and re-exports key types. Add //! module docs | Restrictions: Follow structure.md exactly, use pub use for re-exports | Success: cargo doc generates clean API docs, all types accessible from crate root | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

## Phase 8: Integration Testing

- [x] 8.1 Create integration test for full pipeline
  - File: `rust/tests/pipeline_integration.rs`
  - Test: mock adapter → parse → filter → output
  - Purpose: Verify end-to-end data flow
  - _Leverage: MockAdapter, all domain modules_
  - _Requirements: 3, 4_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: QA Engineer | Task: Create integration test using MockAdapter. Connect, receive 10 samples, verify parsing succeeds, verify filtering smooths values, verify output struct is complete | Restrictions: No real BLE, use mock only | Success: Test passes, demonstrates full pipeline works | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

- [x] 8.2 Create state machine integration test
  - File: `rust/tests/state_machine_integration.rs`
  - Test full connection lifecycle with mock
  - Test reconnection scenario
  - Purpose: Verify state machine with real (mocked) I/O
  - _Leverage: MockAdapter, ConnectionStateMachine_
  - _Requirements: 2, 6_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: QA Engineer | Task: Create integration test. Scenario 1: full connect/stream/disconnect. Scenario 2: simulate disconnection, verify reconnection. Use MockAdapter with configurable failure injection | Restrictions: Test realistic scenarios, not unit-level | Success: Both scenarios pass, state machine handles edge cases | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_

- [ ] 8.3 Add coverage enforcement
  - File: `.github/workflows/ci.yml` (or similar)
  - Run cargo-tarpaulin in CI
  - Fail if coverage < 80%
  - Purpose: Maintain code quality standards
  - _Leverage: cargo-tarpaulin_
  - _Requirements: Non-functional (Code Architecture)_
  - _Prompt: Implement the task for spec hr-telemetry, first run spec-workflow-guide to get the workflow guide then implement the task: Role: DevOps Engineer | Task: Create CI workflow. Steps: cargo fmt --check, cargo clippy, cargo test, cargo tarpaulin --out Xml. Fail if coverage < 80% | Restrictions: Use GitHub Actions syntax, cache cargo dependencies | Success: CI runs on push, enforces quality standards | After completing: Update tasks.md to mark [-] as in-progress before starting, use log-implementation tool to record what was created, then mark [x] when complete_
