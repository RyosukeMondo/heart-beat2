# Tasks Document

## Phase 3: Metrics & Quality - Test Coverage Audit

Establish test coverage measurement and ensure the 80% minimum coverage requirement from product.md is met.

- [ ] 1. Install cargo-tarpaulin
  - File: Development environment setup
  - Install cargo-tarpaulin: cargo install cargo-tarpaulin
  - Verify installation: cargo tarpaulin --version
  - Review tarpaulin documentation for configuration options
  - Purpose: Enable code coverage measurement for Rust
  - _Leverage: cargo-tarpaulin documentation_
  - _Requirements: product.md 80% test coverage_
  - _Prompt: Role: DevOps Engineer | Task: Install and verify cargo-tarpaulin for Rust code coverage measurement | Restrictions: Use latest stable version, verify compatibility with project | Success: cargo-tarpaulin installed, runs successfully on project_

- [ ] 2. Run baseline coverage measurement
  - File: rust/ directory
  - Run: cargo tarpaulin --out Html --output-dir coverage/
  - Review coverage report to identify gaps
  - Document current coverage percentage by module
  - Purpose: Establish baseline coverage and identify gaps
  - _Leverage: cargo-tarpaulin_
  - _Requirements: product.md 80% coverage target_
  - _Prompt: Role: QA Engineer | Task: Run initial code coverage measurement and document baseline coverage by module | Restrictions: Include all test types, generate HTML report, identify modules below 80% | Success: Baseline coverage documented, gaps identified, HTML report generated_

- [ ] 3. Create tarpaulin configuration
  - File: rust/tarpaulin.toml or rust/.tarpaulin.toml
  - Configure excluded paths (generated code, test utilities)
  - Set coverage threshold at 80%
  - Configure output formats (Xml for CI, Html for local)
  - Purpose: Standardize coverage measurement configuration
  - _Leverage: cargo-tarpaulin documentation_
  - _Requirements: product.md 80% coverage_
  - _Prompt: Role: DevOps Engineer | Task: Create tarpaulin configuration file with appropriate exclusions and 80% threshold | Restrictions: Exclude generated code, configure for CI compatibility, enable threshold enforcement | Success: Config file created, threshold enforced, appropriate exclusions_

- [ ] 4. Identify modules below 80% coverage
  - File: Coverage report analysis
  - List modules/files below 80% threshold
  - Prioritize based on criticality (domain > adapters > generated)
  - Create list of specific functions/branches needing tests
  - Purpose: Focus testing effort on coverage gaps
  - _Leverage: Baseline coverage report from task 2_
  - _Requirements: product.md coverage target_
  - _Prompt: Role: QA Engineer | Task: Analyze coverage report and identify specific modules, functions, and branches below 80% coverage | Restrictions: Focus on critical business logic, deprioritize generated code, be specific about gaps | Success: Gap list created, prioritized by criticality, specific test needs identified_

- [ ] 5. Add tests for domain layer gaps
  - File: rust/src/domain/*.rs test modules
  - Add unit tests for uncovered functions in domain layer
  - Focus on edge cases and error paths
  - Ensure critical business logic has comprehensive coverage
  - Purpose: Achieve 80%+ coverage on core business logic
  - _Leverage: rust/src/domain/ modules, existing test patterns_
  - _Requirements: product.md coverage, structure.md domain purity_
  - _Prompt: Role: Rust Developer with testing expertise | Task: Add unit tests to domain layer modules to achieve 80%+ coverage, focusing on uncovered paths | Restrictions: Follow existing test patterns, test edge cases, maintain test quality over quantity | Success: Domain layer coverage >= 80%, edge cases covered, tests are meaningful_

- [ ] 6. Add tests for adapter layer gaps
  - File: rust/src/adapters/*.rs test modules
  - Add tests for untested adapter code paths
  - Use mock dependencies for isolation
  - Test error handling and edge cases
  - Purpose: Achieve 80%+ coverage on adapter implementations
  - _Leverage: rust/src/adapters/ modules, mockall for mocking_
  - _Requirements: product.md coverage_
  - _Prompt: Role: Rust Developer | Task: Add unit tests to adapter layer to achieve 80%+ coverage using mocked dependencies | Restrictions: Mock external dependencies, test error paths, maintain isolation | Success: Adapter layer coverage >= 80%, external deps mocked, error handling tested_

- [ ] 7. Add tests for state machine gaps
  - File: rust/src/state/*.rs test modules
  - Test all state transitions in connectivity and session machines
  - Test invalid transition handling
  - Test state machine edge cases
  - Purpose: Ensure comprehensive state machine coverage
  - _Leverage: rust/src/state/ modules, statig testing patterns_
  - _Requirements: product.md coverage_
  - _Prompt: Role: Rust Developer with state machine expertise | Task: Add comprehensive tests for state machine transitions and edge cases | Restrictions: Test all valid transitions, verify invalid transition handling, use statig patterns | Success: State machine coverage >= 80%, all transitions tested, edge cases covered_

- [ ] 8. Add tests for scheduler/executor gaps
  - File: rust/src/scheduler/*.rs test modules
  - Test session lifecycle (start, pause, resume, stop)
  - Test checkpoint persistence and recovery
  - Test cron scheduling functionality
  - Purpose: Ensure executor has comprehensive coverage
  - _Leverage: rust/src/scheduler/executor.rs, existing test patterns_
  - _Requirements: product.md coverage_
  - _Prompt: Role: Rust Developer | Task: Add comprehensive tests for SessionExecutor covering all lifecycle operations and persistence | Restrictions: Test async operations properly, mock dependencies, cover error cases | Success: Executor coverage >= 80%, lifecycle tested, persistence verified_

- [ ] 9. Update CI workflow for coverage
  - File: .github/workflows/ci.yml or .github/workflows/coverage.yml
  - Add cargo-tarpaulin step to CI
  - Configure coverage threshold enforcement (fail if < 80%)
  - Upload coverage report as artifact
  - Optional: Integrate with Codecov or similar
  - Purpose: Enforce coverage requirement in CI
  - _Leverage: .github/workflows/ existing workflows_
  - _Requirements: ci-cd spec, product.md coverage_
  - _Prompt: Role: DevOps Engineer | Task: Update CI workflow to run coverage measurement and enforce 80% threshold | Restrictions: Fail build if coverage below threshold, upload reports, minimize CI time | Success: CI runs coverage, enforces threshold, uploads reports_

- [ ] 10. Update README with coverage badge
  - File: README.md
  - Add coverage badge showing current percentage
  - Link to coverage reports if published
  - Document how to run coverage locally
  - Purpose: Make coverage status visible to contributors
  - _Leverage: README.md, Codecov or shields.io badges_
  - _Requirements: documentation spec_
  - _Prompt: Role: Technical Writer | Task: Add coverage badge to README and document coverage measurement process | Restrictions: Use dynamic badge, link to reports, keep instructions clear | Success: Badge shows current coverage, linked to reports, local instructions documented_

- [ ] 11. Verify overall coverage >= 80%
  - File: Final coverage report
  - Run full coverage measurement after all tests added
  - Verify overall coverage meets 80% threshold
  - Document final coverage by module
  - Purpose: Validate coverage requirement is met
  - _Leverage: cargo-tarpaulin with configuration_
  - _Requirements: product.md 80% coverage_
  - _Prompt: Role: QA Lead | Task: Run final coverage measurement and verify 80% threshold is met across the codebase | Restrictions: All modules should contribute, no critical gaps, document results | Success: Overall coverage >= 80%, documented, CI enforcement active_
