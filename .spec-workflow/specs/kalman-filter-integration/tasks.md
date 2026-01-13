# Tasks Document

## Phase 1: Critical Fixes - Kalman Filter Integration

Integrate the existing Kalman filter implementation into the HR data pipeline to provide noise-reduced BPM readings as documented in product requirements.

- [ ] 1. Wire KalmanFilter into connect_device HR pipeline
  - File: rust/src/api.rs
  - Replace raw BPM assignment at line 624 with KalmanFilter processing
  - Create thread-safe KalmanFilter instance for each connection
  - Apply filter to incoming HR measurements before emitting to stream
  - Purpose: Achieve ±5 BPM accuracy target through noise reduction
  - _Leverage: rust/src/domain/filters.rs (KalmanFilter implementation)_
  - _Requirements: product.md accuracy metric (±5 BPM vs reference)_
  - _Prompt: Role: Rust Developer specializing in real-time signal processing | Task: Integrate the existing KalmanFilter from domain/filters.rs into the HR data pipeline in api.rs, replacing the raw BPM passthrough at line 624 with filtered values | Restrictions: Must be thread-safe for async context, do not modify the KalmanFilter implementation itself, maintain sub-100ms latency | Success: HR stream emits Kalman-filtered BPM values, filter state persists across measurements within a session, latency remains under 100ms_

- [ ] 2. Add filter state management to HR stream task
  - File: rust/src/api.rs
  - Initialize KalmanFilter with appropriate process/measurement noise parameters
  - Reset filter state on new connection (not on reconnection)
  - Handle filter warm-up period (first few samples may be less accurate)
  - Purpose: Ensure filter operates correctly across connection lifecycle
  - _Leverage: rust/src/domain/filters.rs (KalmanFilter::new, KalmanFilter::update)_
  - _Requirements: product.md session reliability_
  - _Prompt: Role: Embedded Systems Developer with Kalman filter expertise | Task: Implement proper filter state management in the HR stream task, initializing with tuned noise parameters and handling connection lifecycle events | Restrictions: Do not reset filter on reconnection (preserve history), use appropriate noise values for optical HR sensors, maintain deterministic behavior | Success: Filter initializes correctly on connect, persists through reconnections, warm-up period handled gracefully_

- [ ] 3. Update FilteredHeartRate to include filter confidence
  - File: rust/src/domain/heart_rate.rs
  - Add optional confidence/variance field to FilteredHeartRate
  - Populate from KalmanFilter's estimated variance
  - Allow UI to display confidence indicator if desired
  - Purpose: Provide transparency on filter accuracy to users
  - _Leverage: rust/src/domain/filters.rs (KalmanFilter state)_
  - _Requirements: product.md determinism principle_
  - _Prompt: Role: Domain Modeling Expert | Task: Extend FilteredHeartRate struct to include filter confidence/variance information from the Kalman filter state | Restrictions: Field must be optional for backward compatibility, use appropriate precision, document the meaning clearly | Success: FilteredHeartRate includes confidence field, value reflects actual filter variance, FRB regeneration succeeds_

- [ ] 4. Regenerate FRB bindings
  - File: lib/src/bridge/api_generated.dart/*
  - Run flutter_rust_bridge_codegen after FilteredHeartRate changes
  - Verify generated Dart types include new fields
  - Update any Flutter code consuming the updated types
  - Purpose: Ensure Dart side receives filter confidence data
  - _Leverage: scripts/build-rust.sh or flutter_rust_bridge_codegen_
  - _Requirements: tech.md FRB v2 integration_
  - _Prompt: Role: Flutter-Rust Bridge Developer | Task: Regenerate FRB bindings after FilteredHeartRate struct changes, ensuring new fields are available in Dart | Restrictions: Do not manually edit generated files, verify backward compatibility, test compilation on both platforms | Success: FRB codegen completes without errors, Dart types reflect Rust changes, Flutter app compiles successfully_

- [ ] 5. Add Kalman filter integration tests
  - File: rust/src/api.rs (tests module) or rust/tests/kalman_integration.rs
  - Test filter initialization and update cycle
  - Verify filtered output is smoother than raw input
  - Test filter behavior across simulated reconnection
  - Purpose: Ensure filter integration works correctly end-to-end
  - _Leverage: rust/src/adapters/mock_adapter.rs (simulated HR data)_
  - _Requirements: product.md 80% test coverage_
  - _Prompt: Role: QA Engineer with signal processing test expertise | Task: Create integration tests verifying Kalman filter integration in HR pipeline, using mock adapter for simulated data | Restrictions: Tests must be deterministic, verify both smoothing effect and latency, do not require hardware | Success: Tests pass consistently, verify filter reduces noise, confirm latency remains acceptable_

- [ ] 6. Tune filter parameters for Coospo HW9
  - File: rust/src/api.rs or rust/src/domain/filters.rs
  - Adjust process_noise and measurement_noise based on real device data
  - Document chosen parameters and rationale
  - Consider making parameters configurable for future sensor support
  - Purpose: Optimize filter performance for target hardware
  - _Leverage: docs/research.md (sensor characteristics if documented)_
  - _Requirements: product.md ±5 BPM accuracy_
  - _Prompt: Role: Signal Processing Engineer specializing in biomedical sensors | Task: Tune Kalman filter parameters for Coospo HW9 optical sensor characteristics, balancing responsiveness vs noise rejection | Restrictions: Must achieve ±5 BPM accuracy target, avoid over-filtering that masks real HR changes, document tuning rationale | Success: Filter achieves target accuracy on real device, responds appropriately to HR changes during exercise, parameters documented_
