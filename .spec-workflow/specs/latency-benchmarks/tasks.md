# Tasks Document

## Phase 3: Metrics & Quality - Latency Benchmarks

Implement latency measurement and benchmarking to validate the P95 < 100ms requirement from BLE event to UI update.

- [x] 1. Design latency measurement approach
  - File: docs/ or design document
  - Define measurement points: BLE notification → Rust processing → FRB → Flutter UI
  - Plan instrumentation strategy (timestamps at each stage)
  - Consider using tracing spans or custom timing
  - Purpose: Establish clear methodology for latency measurement
  - _Leverage: rust/src/api.rs (HR data flow), tech.md latency requirements_
  - _Requirements: product.md P95 < 100ms requirement_
  - _Prompt: Role: Performance Engineer specializing in real-time systems | Task: Design comprehensive latency measurement approach for HR data pipeline from BLE event to UI update | Restrictions: Instrumentation must be low-overhead, support production measurement, enable CI benchmarking | Success: Clear measurement methodology, defined measurement points, approach for calculating P95_

- [x] 2. Add timestamp to HR data structures
  - File: rust/src/domain/heart_rate.rs
  - Add receive_timestamp field to HeartRateMeasurement
  - Capture high-precision timestamp when BLE notification received
  - Propagate timestamp through FilteredHeartRate to UI
  - Purpose: Enable end-to-end latency calculation
  - _Leverage: std::time::Instant or chrono for timestamps_
  - _Requirements: product.md latency measurement_
  - _Prompt: Role: Rust Developer | Task: Add receive timestamp to HR data structures for latency tracking, capturing time at BLE notification receipt | Restrictions: Use appropriate precision (microseconds), minimal overhead, propagate through pipeline | Success: Timestamp captured at BLE receive, available in Flutter via FRB, accurate timing_

- [x] 3. Instrument BLE notification handler
  - File: rust/src/adapters/btleplug_adapter.rs
  - Record timestamp immediately when BLE notification received
  - Use monotonic clock for accurate duration measurement
  - Log or trace the timestamp for debugging
  - Purpose: Capture start time for latency measurement
  - _Leverage: std::time::Instant, tracing spans_
  - _Requirements: product.md latency_
  - _Prompt: Role: Systems Programmer | Task: Instrument BLE notification handler to capture high-precision receive timestamp | Restrictions: Minimal overhead, use monotonic clock, don't delay processing | Success: Timestamp captured immediately on BLE event, available for latency calculation_

- [ ] 4. Add latency logging in Flutter
  - File: lib/src/screens/workout_screen.dart or lib/src/services/log_service.dart
  - Calculate and log latency when HR data received in UI
  - Use receive_timestamp from Rust vs current time
  - Log P50, P95, P99 latencies periodically
  - Purpose: Measure actual end-to-end latency in production
  - _Leverage: DateTime.now() in Flutter, receive_timestamp from Rust_
  - _Requirements: product.md latency monitoring_
  - _Prompt: Role: Flutter Developer | Task: Add latency calculation and logging in Flutter when HR data is received, computing end-to-end delay | Restrictions: Low overhead, log periodically not every sample, handle clock differences | Success: Latency calculated accurately, percentiles logged, usable for benchmarking_

- [ ] 5. Create Rust benchmark suite
  - File: rust/benches/latency_bench.rs
  - Benchmark HR parsing latency
  - Benchmark Kalman filter processing latency
  - Benchmark state machine transition latency
  - Use criterion for statistical analysis
  - Purpose: Establish baseline and detect regressions in Rust processing
  - _Leverage: criterion crate, rust/Cargo.toml_
  - _Requirements: ci-cd spec benchmark workflow_
  - _Prompt: Role: Rust Performance Engineer | Task: Create criterion benchmark suite measuring latency of HR processing pipeline components | Restrictions: Statistically rigorous, reproducible, CI-compatible | Success: Benchmarks measure key components, results reproducible, baseline established_

- [ ] 6. Add criterion to Cargo.toml
  - File: rust/Cargo.toml
  - Add criterion as dev-dependency
  - Configure benchmark harness
  - Add [[bench]] section for latency benchmarks
  - Purpose: Enable statistical benchmarking in Rust
  - _Leverage: criterion documentation_
  - _Requirements: ci-cd spec_
  - _Prompt: Role: Rust Developer | Task: Add criterion benchmark framework to Cargo.toml with proper configuration | Restrictions: Dev dependency only, configure harness correctly | Success: cargo bench runs successfully, criterion generates reports_

- [ ] 7. Create CI benchmark workflow
  - File: .github/workflows/benchmark.yml
  - Run benchmarks on PR and main branch
  - Compare results against baseline
  - Fail CI if latency regresses beyond threshold
  - Archive benchmark results
  - Purpose: Prevent latency regressions in CI
  - _Leverage: .github/workflows/ existing workflows, criterion-compare-action_
  - _Requirements: ci-cd spec_
  - _Prompt: Role: DevOps Engineer | Task: Create GitHub Actions workflow for running latency benchmarks and detecting regressions | Restrictions: Must compare against baseline, fail on significant regression, archive results | Success: CI runs benchmarks, compares to baseline, fails on regression, results archived_

- [ ] 8. Document latency budget
  - File: docs/LATENCY.md or docs/DEVELOPER-GUIDE.md
  - Document target latency budget allocation across components
  - BLE stack: Xms, Rust processing: Xms, FRB: Xms, Flutter: Xms
  - Document how to measure and debug latency issues
  - Purpose: Provide guidance for maintaining latency requirements
  - _Leverage: Measurement results from tasks 1-7_
  - _Requirements: product.md latency requirement_
  - _Prompt: Role: Technical Writer with performance expertise | Task: Document latency budget allocation and measurement methodology for the HR data pipeline | Restrictions: Be specific about targets, include debugging guidance, keep practical | Success: Clear latency budget documented, measurement instructions provided, debugging guidance included_

- [ ] 9. Validate P95 < 100ms on device
  - File: Manual testing with instrumented build
  - Run workout session on physical device with latency logging
  - Collect latency samples over 30+ minute session
  - Calculate P50, P95, P99 from collected data
  - Verify P95 < 100ms requirement met
  - Purpose: Validate latency requirement in real-world conditions
  - _Leverage: Instrumented build from tasks 2-4_
  - _Requirements: product.md success metrics_
  - _Prompt: Role: QA Performance Engineer | Task: Validate P95 latency requirement on physical Android device during extended workout session | Restrictions: Use real BLE device, test during actual exercise, collect sufficient samples | Success: P95 latency measured < 100ms, data collected and documented, requirement validated_
