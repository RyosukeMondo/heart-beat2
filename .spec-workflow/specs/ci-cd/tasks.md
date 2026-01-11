# Tasks Document

- [x] 1.1 Create main CI workflow
  - File: `.github/workflows/ci.yml`
  - Add jobs: test-rust, test-flutter, lint-rust, lint-flutter
  - Purpose: Automated testing on every push
  - _Leverage: GitHub Actions_
  - _Requirements: 1_
  - _Prompt: Role: DevOps engineer with GitHub Actions expertise | Task: Create ci.yml with workflow triggered on push and pull_request. Jobs: test-rust (cargo test --all), test-flutter (flutter test), lint-rust (cargo clippy, cargo fmt --check), lint-flutter (flutter analyze, dart format --check). Use matrix for multiple Rust versions (stable, beta). Cache cargo and Flutter dependencies. Fail fast enabled | Restrictions: Must complete in <5min, use latest actions versions | Success: Workflow runs on every commit, blocks PR if fails_

- [x] 1.2 Add integration test job
  - File: `.github/workflows/ci.yml` (extend)
  - Add integration-tests job running tests/
  - Purpose: Validate end-to-end flows
  - _Leverage: existing integration tests_
  - _Requirements: 1_
  - _Prompt: Role: CI/CD specialist | Task: Add integration-tests job to ci.yml running cargo test --test '*'. Run after unit tests pass (needs: [test-rust]). Use --no-fail-fast to see all failures. Set timeout-minutes: 10. Upload test logs as artifacts if failure | Restrictions: Must isolate from unit tests, handle timeouts | Success: Integration tests run separately, logs available on failure_

- [x] 2.1 Add coverage workflow
  - File: `.github/workflows/coverage.yml`
  - Use cargo-llvm-cov to measure coverage
  - Upload to Codecov
  - Purpose: Track test coverage
  - _Leverage: cargo-llvm-cov, Codecov_
  - _Requirements: 2_
  - _Prompt: Role: Code quality engineer | Task: Create coverage.yml triggered on push to main and PRs. Install cargo-llvm-cov, run cargo llvm-cov --all-features --lcov --output-path lcov.info. Upload to Codecov. Add coverage threshold check: fail if <80%. Generate HTML report as artifact. Add PR comment with coverage diff | Restrictions: Must install llvm-tools-preview, handle Codecov token | Success: Coverage tracked, PRs show diff, <80% fails_

- [x] 2.2 Add coverage badge to README
  - File: `README.md`
  - Add Codecov badge after CI badge
  - Purpose: Display coverage prominently
  - _Leverage: Codecov badge URL_
  - _Requirements: 2_
  - _Prompt: Role: Documentation maintainer | Task: Add Codecov badge to README.md: [![Coverage](https://codecov.io/gh/USER/REPO/branch/main/graph/badge.svg)](https://codecov.io/gh/USER/REPO). Place after CI badge. Update once Codecov is configured | Restrictions: Use correct repo URL placeholder | Success: Badge displays coverage percentage_

- [x] 3.1 Configure pre-commit hooks
  - File: `.git/hooks/pre-commit` (template), `scripts/install-hooks.sh`
  - Run clippy, fmt, and fast tests before commit
  - Purpose: Catch issues before pushing
  - _Leverage: git hooks_
  - _Requirements: 3_
  - _Prompt: Role: Developer tooling specialist | Task: Create scripts/install-hooks.sh that copies pre-commit hook to .git/hooks/. Hook runs: cargo fmt --check (fail if needed), cargo clippy -- -D warnings (fail on warnings), cargo test --lib (unit tests only, skip slow integration). Print elapsed time. Allow skip with --no-verify. Add install step to README | Restrictions: Must be fast (<30s), provide clear error messages | Success: Hooks install easily, catch common issues_

- [x] 3.2 Add pre-commit framework config
  - File: `.pre-commit-config.yaml`
  - Use pre-commit framework for better hook management
  - Purpose: Standardized hook configuration
  - _Leverage: pre-commit.com framework_
  - _Requirements: 3_
  - _Prompt: Role: Developer experience engineer | Task: Create .pre-commit-config.yaml with hooks: trailing-whitespace, end-of-file-fixer, check-yaml, check-json, cargo-check, clippy, rustfmt. Add installation instructions to docs/development.md. Document how to run pre-commit run --all-files manually | Restrictions: Use official hook repos, keep fast | Success: pre-commit install works, hooks run automatically_

- [x] 4.1 Create release workflow
  - File: `.github/workflows/release.yml`
  - Build CLI binaries for Linux, macOS, Windows
  - Purpose: Automated binary releases
  - _Leverage: GitHub Releases_
  - _Requirements: 4_
  - _Prompt: Role: Release engineering specialist | Task: Create release.yml triggered on push tags v*. Use matrix for targets: x86_64-linux, x86_64-macos, x86_64-windows. Cross-compile with cargo build --release --target. Strip binaries, create tar.gz/zip. Upload to GitHub release with gh release create. Add checksums file. Auto-generate changelog from commits | Restrictions: Must sign binaries, verify builds work | Success: Pushing v1.0.0 tag creates release with binaries_

- [x] 4.2 Add Flutter APK build
  - File: `.github/workflows/release.yml` (extend)
  - Build and sign Android APK
  - Purpose: Release mobile app
  - _Leverage: Flutter build apk_
  - _Requirements: 4_
  - _Prompt: Role: Mobile release engineer | Task: Add android-release job to release.yml. Setup Java and Flutter, build Rust library for arm64-v8a and x86_64, run flutter build apk --release. Sign with GitHub secrets (KEYSTORE, KEY_PASSWORD). Upload APK as artifact and to GitHub release. Add version name from tag | Restrictions: Must handle secrets securely, verify APK is signed | Success: Release includes signed APK_

- [ ] 5.1 Create benchmark suite
  - File: `rust/benches/latency_bench.rs`
  - Benchmark BLE packet → FilteredHeartRate latency
  - Purpose: Track performance over time
  - _Leverage: criterion crate_
  - _Requirements: 5_
  - _Prompt: Role: Performance engineer | Task: Create latency_bench.rs using criterion. Benchmark: parse_heart_rate (packet parsing), kalman_filter.update (filtering), full_pipeline (packet → filtered). Use realistic BLE packets. Set baseline for comparison. Add criterion to dev-dependencies. Create bench job in CI | Restrictions: Benchmarks must be deterministic, run on same hardware | Success: cargo bench runs, tracks performance trends_

- [ ] 5.2 Add benchmark comparison workflow
  - File: `.github/workflows/benchmark.yml`
  - Compare PR benchmarks against main
  - Purpose: Catch performance regressions
  - _Leverage: criterion, GitHub Actions_
  - _Requirements: 5_
  - _Prompt: Role: Performance testing specialist | Task: Create benchmark.yml triggered on PRs. Run benchmarks on main branch, checkout PR, run benchmarks, compare with criterion. Comment on PR with results table. Fail if >10% regression in critical path (full_pipeline). Cache criterion baseline between runs | Restrictions: Must handle baseline storage, account for CI variance | Success: PRs show performance impact, regressions blocked_

- [ ] 5.3 Add latency acceptance test
  - File: `rust/tests/latency_test.rs`
  - Integration test verifying <100ms P95 latency
  - Purpose: Hard requirement validation
  - _Leverage: existing pipeline integration test_
  - _Requirements: 5_
  - _Prompt: Role: QA automation engineer | Task: Create latency_test.rs that runs full pipeline 1000 times, measures end-to-end latency (BLE packet arrival → FilteredHeartRate emit). Calculate P50, P95, P99. Assert P95 < 100ms. Use tokio::time::Instant for measurement. Run in CI as required test | Restrictions: Must be deterministic, account for CI overhead | Success: Test passes consistently, fails if latency regresses_
