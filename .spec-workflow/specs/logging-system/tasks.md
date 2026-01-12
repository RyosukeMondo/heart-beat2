# Tasks Document

- [x] 1.1 Add android_logger dependency to Cargo.toml
  - File: `rust/Cargo.toml`
  - Add android_logger as Android-only dependency using target cfg
  - Purpose: Enable native Android logcat output
  - _Leverage: existing Cargo.toml target-specific dependencies_
  - _Requirements: 3_
  - _Prompt: Implement the task for spec logging-system, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust developer | Task: Add android_logger = "0.13" as a target-specific dependency for Android in Cargo.toml. Use [target.'cfg(target_os = "android")'.dependencies] section. | Restrictions: Do not add as regular dependency, only Android-specific | Success: cargo build succeeds, android_logger available on Android target | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_

- [x] 1.2 Update init_logging to support dual output on Android
  - File: `rust/src/api.rs`
  - Add android_logger initialization alongside FlutterLogWriter
  - Use cfg attributes for Android-specific code
  - Purpose: Logs appear in both Flutter and logcat on Android
  - _Leverage: existing init_logging function, android_logger docs_
  - _Requirements: 3_
  - _Prompt: Implement the task for spec logging-system, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Rust tracing expert | Task: Modify init_logging in api.rs to also initialize android_logger on Android. Use cfg(target_os = "android") to conditionally call android_logger::init_once(). Set appropriate log level filter matching RUST_LOG. | Restrictions: Keep existing FlutterLogWriter functionality, android_logger is additive | Success: Logs appear in both Flutter stream and adb logcat on Android | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_

- [x] 1.3 Create LogService singleton in Flutter
  - File: `lib/src/services/log_service.dart`
  - Implement singleton LogService with subscribe, stream, logs, clear methods
  - Add log buffer with 1000 entry limit
  - Purpose: Centralized log management for Flutter app
  - _Leverage: StreamController, existing service patterns_
  - _Requirements: 2_
  - _Prompt: Implement the task for spec logging-system, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter developer | Task: Create LogService singleton in lib/src/services/log_service.dart. Implement: subscribe(Stream<LogMessage>) to connect to Rust, broadcast stream for listeners, logs getter for all stored logs, clear() method. Limit buffer to 1000 entries (remove oldest). Print to debugPrint in debug mode. | Restrictions: Use singleton pattern, do not use external packages | Success: LogService can receive, store, and broadcast logs | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_

- [ ] 1.4 Initialize logging in main.dart
  - File: `lib/main.dart`
  - Call initPanicHandler() and initLogging() on startup
  - Connect log stream to LogService
  - Purpose: Activate logging system on app start
  - _Leverage: existing main.dart, generated FRB bindings_
  - _Requirements: 1_
  - _Prompt: Implement the task for spec logging-system, first run spec-workflow-guide to get the workflow guide then implement the task: Role: Flutter developer | Task: Update main.dart to call initPanicHandler() and initLogging() after RustLib.init(). Pass the returned Stream<LogMessage> to LogService.instance.subscribe(). Wrap in try-catch for graceful error handling. | Restrictions: Keep existing initialization order, add after RustLib.init() | Success: App starts with logging active, no errors on startup | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_

- [ ] 1.5 Test logging on Android device
  - File: N/A (manual testing)
  - Rebuild APK and test on Pixel 9a
  - Verify logs in adb logcat
  - Purpose: Validate dual logging works
  - _Leverage: adb logcat command_
  - _Requirements: 1, 2, 3_
  - _Prompt: Implement the task for spec logging-system, first run spec-workflow-guide to get the workflow guide then implement the task: Role: QA Engineer | Task: Rebuild APK, install on Pixel 9a. Run adb logcat and filter for heart_beat. Trigger some app actions and verify Rust logs appear in logcat. Also verify app doesn't crash on startup. | Restrictions: Test on real device | Success: Logs visible in adb logcat, app functions normally | After implementation: Mark task [-] as in_progress before starting, use log-implementation tool to record changes, then mark [x] when complete_
