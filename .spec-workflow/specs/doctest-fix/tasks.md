# Tasks Document

## Phase 1: Critical Fixes - Doctest Fix

Fix the failing doctest in export_session that requires tokio_test dependency.

- [x] 1. Analyze failing doctest
  - File: rust/src/api.rs (line 1347)
  - Review the export_session doctest that uses tokio_test::block_on
  - Determine if tokio_test is appropriate or if alternative approach better
  - Consider using tokio::runtime::Runtime::new() instead
  - Purpose: Understand root cause and best fix approach
  - _Leverage: rust/Cargo.toml (current dev dependencies)_
  - _Requirements: ci-cd spec (all tests must pass)_
  - _Prompt: Role: Rust Developer with testing expertise | Task: Analyze the failing export_session doctest and determine the best approach to fix it - either add tokio_test dependency or refactor the doctest | Restrictions: Fix must be minimal and maintainable, prefer not adding dependencies if simple alternative exists | Success: Clear understanding of issue, recommended fix approach identified_

- [x] 2. Fix export_session doctest
  - File: rust/src/api.rs
  - Either add tokio_test to dev-dependencies and update doctest
  - Or refactor doctest to use tokio::runtime::Runtime::new().block_on()
  - Ensure doctest compiles and runs correctly
  - Purpose: Make all doctests pass in CI
  - _Leverage: rust/Cargo.toml, existing doctest patterns in codebase_
  - _Requirements: ci-cd spec_
  - _Prompt: Role: Rust Developer | Task: Fix the export_session doctest so it compiles and runs, using either tokio_test or inline runtime creation | Restrictions: Minimal change approach, follow existing doctest patterns in codebase, ensure doctest actually tests the function | Success: Doctest compiles and passes, cargo test --doc succeeds_

- [x] 3. Audit other async doctests
  - File: rust/src/api.rs and other async modules
  - Check for similar issues in other async function doctests
  - Ensure consistent approach across all async doctests
  - Fix any other failing or ignored doctests if appropriate
  - Purpose: Prevent similar issues and ensure doctest consistency
  - _Leverage: cargo test --doc output_
  - _Requirements: product.md 80% test coverage_
  - _Prompt: Role: QA Engineer | Task: Audit all async doctests in the codebase for similar issues, ensuring consistent async testing approach | Restrictions: Only fix actual issues, don't over-engineer, maintain doctest as documentation | Success: All doctests use consistent async pattern, no failures, doctests serve as useful documentation_

- [x] 4. Verify full test suite passes
  - File: rust/Cargo.toml, rust/src/**
  - Run cargo test to verify all tests pass
  - Run cargo test --doc to verify all doctests pass
  - Check for any new warnings introduced
  - Purpose: Ensure fix doesn't break anything else
  - _Leverage: CI workflow configuration_
  - _Requirements: ci-cd spec_
  - _Prompt: Role: CI/CD Engineer | Task: Verify the complete test suite passes after doctest fixes, including unit tests, integration tests, and doctests | Restrictions: No test regressions allowed, address any new warnings | Success: cargo test passes, cargo test --doc passes, no new warnings_
