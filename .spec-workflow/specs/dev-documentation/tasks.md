# Tasks Document

- [x] 1.1 Update CLAUDE.md with quick reference section
  - File: `CLAUDE.md`
  - Add Development Quick Reference section
  - Include command table for all workflows
  - Add debug log level examples
  - Purpose: Immediate access to common commands
  - _Leverage: existing CLAUDE.md content_
  - _Requirements: 1_
  - _Prompt: Implement the task for spec dev-documentation, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Technical writer | Task: Add "Development Quick Reference" section to CLAUDE.md with: 1) command table for Linux CLI, Linux Desktop, Android Deploy, Android Logs, Run Tests, 2) debug log level examples (RUST_LOG=debug, RUST_LOG=heart_beat=debug), 3) link to docs/DEVELOPER-GUIDE.md for details. | Restrictions: Keep brief, use markdown table | Success: Quick commands visible in CLAUDE.md | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_

- [x] 1.2 Create DEVELOPER-GUIDE.md environment setup section
  - File: `docs/DEVELOPER-GUIDE.md`
  - Document Linux dependencies
  - Document Android SDK/NDK setup
  - Document Flutter configuration
  - Purpose: Complete setup instructions
  - _Leverage: build scripts for reference_
  - _Requirements: 2_
  - _Prompt: Implement the task for spec dev-documentation, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Technical writer | Task: Create docs/DEVELOPER-GUIDE.md starting with Environment Setup section covering: 1) Linux dependencies (libudev-dev, libdbus-1-dev, libssl-dev, pkg-config), 2) Android SDK/NDK setup with paths, 3) Flutter configuration, 4) Rust toolchain with Android targets. | Restrictions: Clear step-by-step instructions | Success: New developer can set up environment | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_

- [x] 1.3 Add development workflows section to DEVELOPER-GUIDE.md
  - File: `docs/DEVELOPER-GUIDE.md` (continue)
  - Document Linux CLI workflow
  - Document Linux Desktop workflow
  - Document Android workflow
  - Document mock mode
  - Purpose: Explain all development paths
  - _Leverage: dev-linux.sh, adb-install.sh_
  - _Requirements: 2_
  - _Prompt: Implement the task for spec dev-documentation, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Technical writer | Task: Add Development Workflows section to DEVELOPER-GUIDE.md covering: 1) Linux CLI (fastest, cargo run --bin cli), 2) Linux Desktop (flutter run -d linux, dev-linux.sh), 3) Android (adb-install.sh, build times), 4) Mock mode (--mock flag). Include when to use each. | Restrictions: Practical examples | Success: Developer knows which workflow to use | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_

- [ ] 1.4 Add debugging section to DEVELOPER-GUIDE.md
  - File: `docs/DEVELOPER-GUIDE.md` (continue)
  - Document debug console usage
  - Document log levels and filtering
  - Document Android logcat tips
  - Document BLE HCI snoop logging
  - Purpose: Explain debugging tools
  - _Leverage: adb-logs.sh, adb-ble-debug.sh_
  - _Requirements: 2_
  - _Prompt: Implement the task for spec dev-documentation, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Technical writer | Task: Add Debugging section to DEVELOPER-GUIDE.md covering: 1) Debug console (triple-tap toggle, filters), 2) Log levels (RUST_LOG env var), 3) Android logcat (adb-logs.sh, grep patterns), 4) BLE HCI snoop (adb-ble-debug.sh enable/disable/status). | Restrictions: Include common issues | Success: Developer can debug effectively | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_

- [ ] 1.5 Add scripts reference section to DEVELOPER-GUIDE.md
  - File: `docs/DEVELOPER-GUIDE.md` (continue)
  - Document all scripts in scripts/
  - Include usage examples
  - Purpose: Script reference
  - _Leverage: scripts/*.sh_
  - _Requirements: 3_
  - _Prompt: Implement the task for spec dev-documentation, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Technical writer | Task: Add Scripts Reference section to DEVELOPER-GUIDE.md documenting all scripts: dev-linux.sh, dev-watch.sh, adb-logs.sh, adb-install.sh, adb-permissions.sh, adb-ble-debug.sh, build-android.sh, build-rust-android.sh, ble-*.sh. Include purpose and usage for each. | Restrictions: Consistent format | Success: All scripts documented | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_
