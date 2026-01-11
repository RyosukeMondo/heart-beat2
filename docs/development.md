# Development Guide

Welcome to Heart Beat development! This guide will help you set up your environment, understand the development workflow, and contribute effectively to the project.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Code Standards](#code-standards)
- [Pull Request Process](#pull-request-process)
- [Debugging](#debugging)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

Before you begin, ensure you have the following installed:

| Tool | Version | Purpose | Installation |
|------|---------|---------|--------------|
| **Rust** | 1.75+ | Core library compilation | [rustup.rs](https://rustup.rs) |
| **Flutter** | 3.16+ | Mobile app framework | [flutter.dev](https://docs.flutter.dev/get-started/install) |
| **Android SDK** | API 26-34 | Android build target | Via Android Studio |
| **Android NDK** | r25c+ | Rust cross-compilation | Via SDK Manager |
| **Git** | 2.0+ | Version control | [git-scm.com](https://git-scm.com) |

### System Dependencies (Linux)

For Bluetooth and D-Bus support on Linux:

```bash
sudo apt-get update
sudo apt-get install -y libudev-dev libdbus-1-dev
```

### Rust Targets

Add Android cross-compilation targets:

```bash
rustup target add aarch64-linux-android armv7-linux-androideabi
```

### Verify Installation

```bash
# Check Rust
rustc --version  # Should be 1.75 or higher
cargo --version

# Check Flutter
flutter --version  # Should be 3.16 or higher
flutter doctor     # Check for any issues

# Check Android tools
sdkmanager --list | grep -E "ndk|platform"
```

## Initial Setup

### 1. Clone the Repository

```bash
git clone https://github.com/heart-beat/heart-beat.git
cd heart-beat
```

### 2. Build Rust Core

```bash
cd rust
cargo build
cargo test
```

**Expected output:**
- Build completes without errors
- All tests pass (should see ~80+ tests)

### 3. Build Flutter App

```bash
cd ..
flutter pub get
flutter build apk --debug
```

### 4. Try the CLI Tool

The CLI is the fastest way to develop and test without mobile builds:

```bash
cd rust
cargo run --bin cli -- --help
```

**Test basic functionality:**

```bash
# Scan for BLE devices (requires Bluetooth adapter)
cargo run --bin cli -- scan

# Run a mock training session
cargo run --bin cli -- mock session --plan ../docs/plans/beginner-base-building.json

# Create a new training plan interactively
cargo run --bin cli -- plan create
```

## Development Workflow

### Daily Development Cycle

1. **Create a feature branch**

```bash
git checkout -b feature/my-feature-name
```

2. **Make changes**

Edit code in your preferred editor. The project uses standard Rust and Dart tooling.

**Recommended editors:**
- VS Code with Rust Analyzer + Flutter extensions
- IntelliJ IDEA / Android Studio with Rust + Flutter plugins
- Vim/Neovim with rust-analyzer LSP

3. **Test your changes**

```bash
# In rust/ directory
cargo test
cargo clippy
cargo fmt
```

4. **Commit with clear messages**

```bash
git add .
git commit -m "feat(module): add new feature

Detailed description of what changed and why."
```

**Commit message format:**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Test additions/changes
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `chore`: Build/tooling changes

**Examples:**
```
feat(domain): add heart rate variability calculation
fix(cli): correct zone calculation display
docs(api): add examples for training plan API
test(filters): add Kalman filter property tests
```

5. **Push and create a pull request**

```bash
git push -u origin feature/my-feature-name
```

Then create a PR on GitHub (see [Pull Request Process](#pull-request-process)).

### CLI-First Development

**Why develop with the CLI first:**

- ⚡ **Fast iteration** - No mobile build wait times (seconds vs minutes)
- 🔍 **Better debugging** - Direct terminal output, easy logging
- 🧪 **Easy testing** - Mock adapters simulate sensors without hardware
- 📊 **Rich feedback** - TUI shows real-time session state

**Typical workflow:**

```bash
# 1. Develop feature in Rust with CLI
cd rust
cargo run --bin cli -- mock session --plan ../docs/plans/5k-training.json

# 2. Test with real BLE device if available
cargo run --bin cli -- scan
cargo run --bin cli -- session start

# 3. Once working, build Flutter app
cd ..
flutter build apk --debug
flutter install
```

## Testing

### Running Tests

**Run all tests:**

```bash
cd rust
cargo test
```

**Run specific module tests:**

```bash
cargo test --test domain  # Domain logic tests
cargo test --test state   # State machine tests
cargo test filters        # Filter tests (unit tests)
```

**Run with output:**

```bash
cargo test -- --nocapture
```

**Run specific test:**

```bash
cargo test test_calculate_zone_all_zones
```

### Test Categories

1. **Unit tests** - In `#[cfg(test)]` modules within source files
2. **Integration tests** - In `tests/` directory
3. **Property tests** - Using `proptest` for algorithm validation
4. **Mock tests** - Using `mockall` for adapter testing

### Coverage

Generate code coverage report:

```bash
# Install tarpaulin (one time)
cargo install cargo-tarpaulin

# Generate coverage
cargo tarpaulin --out Html --output-dir coverage --all-features --workspace

# Open report
xdg-open coverage/index.html  # Linux
open coverage/index.html      # macOS
```

**Coverage requirements:**
- **Minimum:** 80% line coverage (enforced by CI)
- **Target:** 85%+ for new code
- **Critical paths:** 95%+ (domain logic, state machines)

### Writing Tests

**Example unit test:**

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_zone_calculation() {
        let hr = HeartRateMeasurement::new(150, Utc::now());
        let zone = calculate_zone(150, 200).unwrap();
        assert_eq!(zone, Some(Zone::Zone3));
    }
}
```

**Example property test:**

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn test_filter_stability(bpm in 40u16..220u16) {
        let mut filter = KalmanFilter::new();
        let result = filter.update(bpm);
        assert!(result >= 30 && result <= 230);
    }
}
```

**Example mock test:**

```rust
use mockall::mock;

mock! {
    BleAdapter {}

    #[async_trait]
    impl BleAdapter for BleAdapter {
        async fn scan(&mut self) -> Result<Vec<Device>>;
    }
}

#[tokio::test]
async fn test_scan_with_mock() {
    let mut mock = MockBleAdapter::new();
    mock.expect_scan()
        .returning(|| Ok(vec![Device::new("Test")]));

    let result = mock.scan().await;
    assert!(result.is_ok());
}
```

## Code Standards

### Rust Code Style

**Formatting:**

```bash
cargo fmt
```

**All code must pass:**

```bash
cargo fmt --check  # CI will fail if not formatted
```

**Linting:**

```bash
cargo clippy --all-targets --all-features -- -D warnings
```

**No warnings allowed** - CI enforces zero clippy warnings.

### Code Quality Rules

From CI configuration and best practices:

1. **Line length:** Prefer ≤100 characters (rustfmt default)
2. **Documentation:** All public items must have `///` doc comments
3. **Error handling:** Use `anyhow::Result` for fallible functions
4. **Async:** Use `#[async_trait]` for async trait methods
5. **Naming:**
   - Types: `PascalCase`
   - Functions: `snake_case`
   - Constants: `SCREAMING_SNAKE_CASE`
   - Modules: `snake_case`

### Documentation Standards

**Every public item needs doc comments:**

```rust
/// Calculate the training zone for a given heart rate.
///
/// Uses the percentage of maximum heart rate to determine the zone.
/// Zones range from 1 (Recovery) to 5 (Maximum).
///
/// # Arguments
///
/// * `bpm` - Current heart rate in beats per minute
/// * `max_hr` - User's maximum heart rate
///
/// # Returns
///
/// * `Ok(Some(Zone))` - The appropriate training zone
/// * `Ok(None)` - BPM is below training threshold (< 50% max)
/// * `Err` - max_hr is invalid
///
/// # Examples
///
/// ```
/// use heart_beat::domain::training_plan::calculate_zone;
/// use heart_beat::domain::heart_rate::Zone;
///
/// let zone = calculate_zone(140, 200).unwrap();
/// assert_eq!(zone, Some(Zone::Zone3));
/// ```
pub fn calculate_zone(bpm: u16, max_hr: u16) -> Result<Option<Zone>> {
    // Implementation...
}
```

**Documentation checklist:**
- [ ] Brief description (one line)
- [ ] Detailed explanation if complex
- [ ] All arguments documented
- [ ] Return value documented
- [ ] Errors/panics documented if applicable
- [ ] Example code that compiles and runs

### Flutter/Dart Standards

Follow official Dart style guide:

```bash
flutter format lib/
flutter analyze
```

## Pull Request Process

### Before Creating a PR

1. **Ensure all tests pass:**

```bash
cd rust
cargo test --all-features
cargo clippy --all-targets --all-features -- -D warnings
cargo fmt --check
```

2. **Update documentation if needed:**
   - Add/update doc comments
   - Update README.md if adding user-facing features
   - Update architecture.md if changing structure

3. **Test on real device if possible:**

```bash
flutter build apk --debug
flutter install
# Test the feature manually
```

### Creating the PR

1. **Push your branch:**

```bash
git push -u origin feature/my-feature-name
```

2. **Create PR on GitHub:**
   - Use a clear, descriptive title
   - Fill out the PR template (if present)
   - Reference any related issues: "Fixes #123"
   - Add screenshots/videos for UI changes

3. **PR description should include:**
   - **What** changed (summary)
   - **Why** it changed (motivation)
   - **How** to test it (steps)
   - **Screenshots** (if UI changes)

**Example PR description:**

```markdown
## Summary
Add RMSSD calculation for heart rate variability analysis.

## Motivation
Users need HRV metrics to assess recovery status. RMSSD is the most
reliable short-term HRV measure.

## Changes
- Add `calculate_rmssd()` function to hrv module
- Add unit tests and property tests
- Update CLI to display RMSSD in session summary

## Testing
1. Run: `cargo test hrv`
2. Run mock session: `cargo run --bin cli -- mock session --plan ../docs/plans/recovery-run.json`
3. Verify RMSSD displayed in session summary

## Screenshots
![HRV Display](screenshot.png)
```

### Review Process

**What reviewers check:**
- ✅ Tests pass and coverage maintained
- ✅ Code follows style guidelines
- ✅ Documentation is complete
- ✅ Changes are focused and logical
- ✅ No breaking changes to public API (unless justified)

**Responding to feedback:**
- Address all comments (either by changing code or explaining why not)
- Mark conversations as resolved once addressed
- Push new commits (don't force-push during review)

### After Approval

Once approved:
- **Squash and merge** (preferred for clean history)
- **Ensure commit message is clear** (edit if needed)
- **Delete branch** after merge

## Debugging

### Enabling Logs

Heart Beat uses `tracing` for structured logging:

```bash
# Enable all logs
RUST_LOG=heart_beat=trace cargo run --bin cli -- scan

# Enable specific module logs
RUST_LOG=heart_beat::state=debug cargo run --bin cli -- session start

# Multiple modules
RUST_LOG=heart_beat::domain=debug,heart_beat::adapters=trace cargo run
```

**Log levels:**
- `error` - Errors only
- `warn` - Warnings and errors
- `info` - Informational messages (default for CLI)
- `debug` - Detailed debugging info
- `trace` - Very verbose output

### CLI Debugging Tips

**Test with mock adapter:**

```bash
# Simulate perfect heart rate data
cargo run --bin cli -- mock scan
cargo run --bin cli -- mock session --plan ../docs/plans/5k-training.json

# Simulate specific HR patterns
cargo run --bin cli -- mock session --pattern ramp --start-bpm 100 --end-bpm 180 --duration 600

# Simulate dropout issues
cargo run --bin cli -- mock session --pattern dropout --dropout-rate 0.1
```

**Inspect state machine transitions:**

```bash
# Enable state machine debug logs
RUST_LOG=heart_beat::state=trace cargo run --bin cli -- session start
```

**Test BLE scanning:**

```bash
# Scan and show all BLE devices
cargo run --bin cli -- scan

# Scan with extended info
RUST_LOG=heart_beat::adapters::btleplug=debug cargo run --bin cli -- scan
```

### Using Rust Debugger

**With GDB/LLDB:**

```bash
# Build with debug symbols
cargo build

# Run with debugger
rust-gdb target/debug/cli
# or
rust-lldb target/debug/cli

# Set breakpoints, etc.
(gdb) break domain::filters::kalman_filter
(gdb) run -- scan
```

**With VS Code:**

Add to `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "lldb",
      "request": "launch",
      "name": "Debug CLI",
      "cargo": {
        "args": ["build", "--bin=cli", "--manifest-path=rust/Cargo.toml"]
      },
      "args": ["scan"],
      "cwd": "${workspaceFolder}/rust"
    }
  ]
}
```

### Flutter Debugging

**Run in debug mode:**

```bash
flutter run
```

**Use Flutter DevTools:**

```bash
flutter pub global activate devtools
flutter pub global run devtools
```

**Check Rust-Flutter bridge:**

```bash
# Rebuild bridge bindings
flutter_rust_bridge_codegen generate

# Check generated Dart code
cat lib/src/bridge_generated.dart
```

## Troubleshooting

### Common Issues

#### 1. Bluetooth Permissions (Linux)

**Error:** `Permission denied` when scanning for BLE devices

**Solution:**

```bash
# Add user to bluetooth group
sudo usermod -a -G bluetooth $USER

# Or run with sudo (not recommended for regular development)
sudo cargo run --bin cli -- scan

# Reboot for group membership to take effect
sudo reboot
```

#### 2. Android NDK Not Found

**Error:** `error: linker 'aarch64-linux-android-gcc' not found`

**Solution:**

```bash
# Set NDK path in environment
export ANDROID_NDK_HOME=/path/to/android/sdk/ndk/25.2.9519653

# Or in ~/.bashrc / ~/.zshrc:
echo 'export ANDROID_NDK_HOME=$HOME/Android/Sdk/ndk/25.2.9519653' >> ~/.bashrc
source ~/.bashrc
```

#### 3. Flutter Build Fails After Rust Changes

**Error:** `Rust compilation failed` in Flutter build

**Solution:**

```bash
# Clean and rebuild Rust artifacts
cd rust
cargo clean
cargo build --release --target aarch64-linux-android

# Clean Flutter build cache
cd ..
flutter clean
flutter pub get
flutter build apk
```

#### 4. Tests Fail with BLE Errors

**Error:** Tests fail with `Bluetooth adapter not available`

**Solution:**

Tests should use mock adapters. If you see BLE errors:

```rust
// Bad - tries to use real BLE in tests
#[tokio::test]
async fn test_scan() {
    let adapter = BtleplugAdapter::new().await.unwrap();
    // ...
}

// Good - uses mock adapter
#[tokio::test]
async fn test_scan() {
    let mut mock = MockBleAdapter::new();
    mock.expect_scan().returning(|| Ok(vec![]));
    // ...
}
```

#### 5. High Memory Usage in Tests

**Error:** `SIGKILL` or out of memory during `cargo test`

**Solution:**

```bash
# Run tests sequentially instead of parallel
cargo test -- --test-threads=1

# Increase test timeout
cargo test -- --test-threads=1 --timeout=300
```

#### 6. CI Fails but Local Tests Pass

**Common causes:**
- Formatting not checked: Run `cargo fmt` before committing
- Clippy warnings: Run `cargo clippy -- -D warnings`
- Coverage too low: Check `cargo tarpaulin` output

**Solution:**

```bash
# Run full CI checks locally
cd rust
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all-features
cargo tarpaulin --out Xml --output-dir ../coverage
```

### Getting Help

**If you're stuck:**

1. **Check existing issues:** [GitHub Issues](https://github.com/heart-beat/heart-beat/issues)
2. **Search discussions:** [GitHub Discussions](https://github.com/heart-beat/heart-beat/discussions)
3. **Ask in Discord:** [Community Discord](#) (if available)
4. **Create an issue:** With minimal reproducible example

**When reporting issues, include:**
- Operating system and version
- Rust version (`rustc --version`)
- Flutter version (`flutter --version`)
- Full error message and stack trace
- Steps to reproduce

---

## Additional Resources

- **Architecture Guide:** `docs/architecture.md` - Understand the hexagonal design
- **User Guide:** `docs/user-guide.md` - End-user documentation
- **API Examples:** `docs/api-examples.md` - Library usage patterns
- **Module READMEs:** `rust/src/*/README.md` - Module-specific docs

---

## Quick Reference

**Common commands:**

```bash
# Build and test Rust
cargo build
cargo test
cargo clippy
cargo fmt

# Build Flutter app
flutter pub get
flutter build apk

# Run CLI
cargo run --bin cli -- <command>

# Generate docs
cargo doc --no-deps --open

# Check coverage
cargo tarpaulin --out Html --output-dir coverage

# Format all code
cargo fmt
flutter format lib/
```

**File structure:**

```
heart-beat/
├── rust/               # Rust core library
│   ├── src/
│   │   ├── domain/    # Business logic
│   │   ├── ports/     # Trait interfaces
│   │   ├── adapters/  # External implementations
│   │   ├── state/     # State machines
│   │   └── scheduler/ # Session execution
│   ├── tests/         # Integration tests
│   └── Cargo.toml
├── lib/               # Flutter app
├── docs/              # Documentation
└── README.md
```

Happy coding! 🚀
