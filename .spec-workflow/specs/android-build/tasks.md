# Tasks Document

- [x] 1.1 Configure FRB codegen
  - File: `flutter_rust_bridge.yaml`
  - Configure input (api.rs) and output (api_generated.dart)
  - Purpose: Enable Dart binding generation
  - _Leverage: FRB v2 documentation_
  - _Requirements: 1_
  - _Prompt: Role: Flutter FFI integration specialist | Task: Create flutter_rust_bridge.yaml with rust_input: ["rust/src/api.rs"], dart_output: ["lib/src/bridge/api_generated.dart"], llvm_path pointing to system LLVM. Configure for FRB v2. Add build dependencies to pubspec.yaml: flutter_rust_bridge: ^2.0.0, ffigen: ^9.0.0 | Restrictions: Must match FRB 2.x config format | Success: flutter_rust_bridge_codegen runs without errors_

- [x] 1.2 Run FRB codegen
  - Command: `flutter_rust_bridge_codegen`
  - Generate Dart bindings from api.rs
  - Purpose: Create Flutter ↔ Rust bridge
  - _Leverage: flutter_rust_bridge.yaml_
  - _Requirements: 1_
  - _Prompt: Role: Build automation engineer | Task: Run flutter_rust_bridge_codegen to generate bindings. Verify lib/src/bridge/api_generated.dart is created with functions: scanDevices, connectDevice, disconnect, startMockMode, getHrStreamReceiver. Check that DiscoveredDevice and FilteredHeartRate classes are generated. Add .frb.dart files to .gitignore | Restrictions: Must regenerate when api.rs changes | Success: Generated Dart code compiles, types match Rust_

- [x] 2.1 Install Android NDK and targets
  - Setup: Android NDK r25c, Rust targets
  - Install aarch64-linux-android, armv7-linux-androideabi, x86_64-linux-android
  - Purpose: Enable cross-compilation for Android
  - _Leverage: rustup, Android Studio_
  - _Requirements: 2_
  - _Prompt: Role: Android native development specialist | Task: Document installation: rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android. Install Android NDK r25c via Android Studio SDK Manager. Set ANDROID_NDK_HOME env var. Create rust/.cargo/config.toml with linker configuration for each target | Restrictions: Must use NDK r25c or later, configure linkers correctly | Success: cargo build --target aarch64-linux-android succeeds_

- [x] 2.2 Create Cargo config for Android
  - File: `rust/.cargo/config.toml`
  - Configure linkers for each Android target
  - Purpose: Enable cross-compilation
  - _Leverage: NDK toolchains_
  - _Requirements: 2_
  - _Prompt: Role: Rust cross-compilation expert | Task: Create rust/.cargo/config.toml with [target.aarch64-linux-android], [target.armv7-linux-androideabi], [target.x86_64-linux-android] sections. Set linker to NDK clang: linker = "path/to/ndk/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android30-clang". Configure ar for each target. Add ANDROID_NDK_HOME env var check | Restrictions: NDK path must be configurable, support NDK r25c+ | Success: Cross-compilation works for all targets_

- [ ] 2.3 Create build script for Rust libraries
  - File: `scripts/build-rust-android.sh`
  - Compile Rust for all Android architectures
  - Purpose: Build native libraries for APK
  - _Leverage: cargo build --target_
  - _Requirements: 2_
  - _Prompt: Role: Mobile build engineer | Task: Create build-rust-android.sh that: checks ANDROID_NDK_HOME is set, builds for aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android using cargo build --release --target, strips binaries with llvm-strip, copies to android/app/src/main/jniLibs/[arm64-v8a,armeabi-v7a,x86_64,x86]/libheart_beat.so. Add --debug flag for debug builds | Restrictions: Must handle errors, show progress | Success: Script builds all architectures, copies to correct locations_

- [ ] 3.1 Update AndroidManifest.xml
  - File: `android/app/src/main/AndroidManifest.xml`
  - Add BLE permissions and configure app
  - Purpose: Enable Bluetooth and permissions
  - _Leverage: Android documentation_
  - _Requirements: 3_
  - _Prompt: Role: Android platform developer | Task: Update AndroidManifest.xml: add <uses-permission> for BLUETOOTH, BLUETOOTH_ADMIN, BLUETOOTH_SCAN, BLUETOOTH_CONNECT, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION. Add <uses-feature android:name="android.hardware.bluetooth_le" android:required="true"/>. Set minSdkVersion 26, targetSdkVersion 34. Add <application android:usesCleartextTraffic="false"> | Restrictions: Follow Android 12+ permission model | Success: Permissions requested correctly on all Android versions_

- [ ] 3.2 Configure Gradle for native libraries
  - File: `android/app/build.gradle`
  - Configure NDK, ABI filters, and Rust integration
  - Purpose: Link native libraries
  - _Leverage: Android Gradle plugin_
  - _Requirements: 2, 3_
  - _Prompt: Role: Android build specialist | Task: Update android/app/build.gradle: set minSdkVersion 26, targetSdkVersion 34. Add ndk { abiFilters 'arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86' }. Configure sourceSets to include jniLibs. Add buildTypes for release (minifyEnabled, shrinkResources). Set compileSdkVersion 34 | Restrictions: Must support all architectures, enable ProGuard for release | Success: APK includes native libraries for all ABIs_

- [ ] 3.3 Add Rust panic handler
  - File: `rust/src/lib.rs`
  - Configure panic handler to catch Rust panics
  - Purpose: Prevent app crashes from Rust panics
  - _Leverage: std::panic::catch_unwind_
  - _Requirements: 3_
  - _Prompt: Role: Rust error handling specialist | Task: Add panic handler in lib.rs using std::panic::set_hook. On panic, log error with tracing::error, convert to Dart exception via FRB. Wrap API functions with catch_unwind. Add panic = 'abort' to Cargo.toml for release profile to reduce size | Restrictions: Must not crash app, provide useful error messages | Success: Rust panics become Dart exceptions with stack traces_

- [ ] 4.1 Create complete build script
  - File: `build-android.sh`
  - One-command build for Android APK
  - Purpose: Simplify build process
  - _Leverage: build-rust-android.sh, flutter build_
  - _Requirements: 4_
  - _Prompt: Role: DevOps automation engineer | Task: Create build-android.sh that: runs flutter_rust_bridge_codegen, calls scripts/build-rust-android.sh (release or debug based on flag), runs flutter build apk --release (or --debug). Add --clean flag to run flutter clean first. Add --architectures flag to build specific ABIs. Show build time and APK size. Add usage help | Restrictions: Must handle errors gracefully, provide progress feedback | Success: ./build-android.sh produces working APK_

- [ ] 4.2 Add development helper scripts
  - Files: `scripts/dev-setup.sh`, `scripts/check-deps.sh`
  - Automate development environment setup
  - Purpose: Streamline onboarding
  - _Leverage: rustup, flutter, Android SDK_
  - _Requirements: 4_
  - _Prompt: Role: Developer experience engineer | Task: Create dev-setup.sh that: checks for Rust (installs via rustup if missing), checks Flutter (shows install instructions), checks Android SDK/NDK (shows install instructions), installs Rust Android targets, runs flutter pub get. Create check-deps.sh that verifies all dependencies with versions. Add to docs/development.md | Restrictions: Must be idempotent, non-destructive | Success: New developer can run ./scripts/dev-setup.sh and start developing_

- [ ] 5.1 Configure logging bridge
  - File: `rust/src/api.rs`
  - Forward Rust tracing logs to Flutter
  - Purpose: Unified logging for debugging
  - _Leverage: tracing, flutter_rust_bridge_
  - _Requirements: 5_
  - _Prompt: Role: Logging infrastructure specialist | Task: Add init_logging() function in api.rs that sets up tracing subscriber forwarding to Flutter via FRB StreamSink. On Flutter side, receive logs and print with debugPrint. Use env var RUST_LOG for level control. Add timestamp and module path to log format | Restrictions: Must be async-safe, handle high log volume | Success: Rust logs appear in flutter logs output_

- [ ] 5.2 Create debugging guide
  - File: `docs/debugging-android.md`
  - Document debugging workflow and common issues
  - Purpose: Help developers debug Android issues
  - _Leverage: flutter logs, adb, Android Studio_
  - _Requirements: 5_
  - _Prompt: Role: Mobile debugging specialist | Task: Create debugging-android.md with: How to view logs (flutter logs, adb logcat), How to debug Rust (lldb, symbols), How to debug Dart (DevTools, breakpoints), Common issues (library not found, permission denied, panics), Performance profiling (Android Studio profiler). Add troubleshooting flowchart | Restrictions: Include concrete commands and screenshots | Success: Developer can debug most issues following guide_

- [ ] 5.3 Add integration test for FRB
  - File: `integration_test/frb_test.dart`
  - Test Rust ↔ Flutter communication
  - Purpose: Validate FRB integration
  - _Leverage: patrol, flutter_test_
  - _Requirements: 1, 5_
  - _Prompt: Role: Integration testing engineer | Task: Create frb_test.dart that: calls scanDevices and verifies result type, starts mock mode and streams HR data verifying updates, tests error handling (invalid device ID), tests async cancellation. Use flutter test integration_test/frb_test.dart to run | Restrictions: Must use mock adapter, not require real device | Success: Test passes, validates all FRB functions_
