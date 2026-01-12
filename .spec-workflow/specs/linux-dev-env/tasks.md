# Tasks Document

- [x] 1.1 Add Flutter Linux desktop support
  - File: `linux/` directory (created by Flutter)
  - Run `flutter create --platforms=linux .` to add Linux support
  - Configure CMakeLists.txt for Rust library linking
  - Purpose: Enable flutter run -d linux
  - _Leverage: Flutter desktop documentation_
  - _Requirements: 1_
  - _Prompt: Implement the task for spec linux-dev-env, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter developer with desktop experience | Task: Add Linux desktop support by running `flutter create --platforms=linux .` in project root. Then update linux/CMakeLists.txt to link the Rust library (libheart_beat.so from rust/target/release/). Verify flutter run -d linux works. | Restrictions: Use standard Flutter Linux setup, minimal custom CMake | Success: flutter run -d linux launches the app | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_

- [ ] 1.2 Create dev-linux.sh script
  - File: `scripts/dev-linux.sh`
  - Build Rust library and launch Flutter Linux
  - Add --release flag option
  - Purpose: One-command development workflow
  - _Leverage: existing scripts pattern_
  - _Requirements: 2_
  - _Prompt: Implement the task for spec linux-dev-env, first run spec-workflow-guide to get the workflow guide then implement the task: Role: DevOps engineer | Task: Create scripts/dev-linux.sh that: 1) cd rust && cargo build --release, 2) cd .. && flutter run -d linux. Support --release flag for optimized build. Add color output and error handling. Make executable with chmod +x. | Restrictions: Keep simple and readable | Success: ./scripts/dev-linux.sh builds and runs app | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_

- [ ] 1.3 Create dev-watch.sh script
  - File: `scripts/dev-watch.sh`
  - Use cargo-watch for auto-rebuild on Rust changes
  - Restart Flutter on rebuild
  - Purpose: Continuous development workflow
  - _Leverage: cargo-watch crate_
  - _Requirements: 2_
  - _Prompt: Implement the task for spec linux-dev-env, first run spec-workflow-guide to get the workflow guide then implement the task: Role: DevOps engineer | Task: Create scripts/dev-watch.sh that uses cargo-watch to monitor Rust file changes and auto-rebuild. When rebuild completes, restart the Flutter app. Include instructions to install cargo-watch if not present. | Restrictions: Require cargo-watch, handle graceful restart | Success: Rust changes trigger auto-rebuild | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_

- [ ] 1.4 Verify CLI works on Linux
  - File: N/A (testing)
  - Test `cargo run --bin cli -- devices scan`
  - Test `cargo run --bin cli -- session start --mock`
  - Purpose: Validate CLI development path
  - _Leverage: existing CLI code_
  - _Requirements: 3_
  - _Prompt: Implement the task for spec linux-dev-env, first run spec-workflow-guide to get the workflow guide then implement the task: Role: QA Engineer | Task: Test the CLI on Linux: 1) cargo run --bin cli -- --help, 2) cargo run --bin cli -- devices scan (with Bluetooth on), 3) cargo run --bin cli -- session start --mock. Document any issues found. | Restrictions: Test on Linux with BlueZ | Success: CLI commands work as expected | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_

- [ ] 1.5 Test Flutter Linux app with real BLE
  - File: N/A (testing)
  - Run Flutter Linux app
  - Test BLE scanning for Coospo HW9
  - Purpose: Validate full Linux development workflow
  - _Leverage: dev-linux.sh script_
  - _Requirements: 1, 3_
  - _Prompt: Implement the task for spec linux-dev-env, first run spec-workflow-guide to get the workflow guide then implement the task: Role: QA Engineer | Task: Use ./scripts/dev-linux.sh to launch the app. Test BLE scanning functionality - verify it can discover the Coospo HW9 heart rate monitor. Test connection if scan works. Document results. | Restrictions: Need Linux machine with Bluetooth | Success: App scans and finds BLE devices on Linux | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_
