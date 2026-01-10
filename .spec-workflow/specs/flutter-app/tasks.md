# Tasks Document

- [x] 1.1 Create pubspec.yaml with dependencies
  - File: `pubspec.yaml`
  - Add Flutter SDK, flutter_rust_bridge, flutter_background_service, permission_handler, shared_preferences
  - Configure assets and app metadata
  - Purpose: Initialize Flutter project
  - _Leverage: tech.md Flutter dependencies table_
  - _Requirements: 1_
  - _Prompt: Role: Flutter project specialist | Task: Create pubspec.yaml with name: heart_beat, Flutter SDK, dependencies: flutter_rust_bridge (2.x), flutter_background_service, permission_handler, shared_preferences. Add dev_dependencies: flutter_test, patrol. Set up assets folder | Restrictions: Use versions compatible with Android API 26+ | Success: flutter pub get succeeds_

- [x] 1.2 Configure FRB codegen
  - File: `flutter_rust_bridge.yaml`, `lib/src/bridge/`
  - Set up FRB codegen to generate Dart bindings from api.rs
  - Create bridge directory structure
  - Purpose: Enable Dart-Rust communication
  - _Leverage: rust/src/api.rs_
  - _Requirements: 1_
  - _Prompt: Role: FRB integration expert | Task: Create flutter_rust_bridge.yaml pointing to rust/src/api.rs. Set output to lib/src/bridge/api_generated.dart. Run flutter_rust_bridge_codegen to generate bindings. Verify scanDevices(), connectDevice(), createHrStream() appear in generated code | Restrictions: Must match api.rs exports exactly | Success: Codegen runs without errors, bindings generated_

- [x] 1.3 Create main.dart and app structure
  - File: `lib/main.dart`, `lib/src/app.dart`
  - Set up MaterialApp with routing and theme
  - Initialize FRB before runApp
  - Purpose: Bootstrap Flutter application
  - _Leverage: Flutter MaterialApp patterns_
  - _Requirements: 1_
  - _Prompt: Role: Flutter app architect | Task: Create main.dart calling RustLib.init() then runApp(MyApp()). Create app.dart with MaterialApp, theme: ThemeData.from(colorScheme: ColorScheme.fromSeed()), routes: '/' -> HomeScreen, '/session' -> SessionScreen, '/settings' -> SettingsScreen. Use Material Design 3 | Restrictions: Must initialize FRB before runApp | Success: App launches showing HomeScreen_

- [x] 2.1 Implement HomeScreen with scan
  - File: `lib/src/screens/home_screen.dart`
  - Create HomeScreen with "Scan for Devices" button
  - Request Bluetooth permissions and call scanDevices()
  - Purpose: Device discovery UI
  - _Leverage: lib/src/bridge/api_generated.dart_
  - _Requirements: 2_
  - _Prompt: Role: Flutter UI developer | Task: Create HomeScreen StatefulWidget with ElevatedButton "Scan for Devices". On tap, request Bluetooth permissions via permission_handler. If granted, call api.scanDevices(), show loading indicator. On result, display ListView of devices with name and RSSI. On tap, navigate to /session with device_id argument | Restrictions: Handle permission denial with SnackBar | Success: User can scan and see devices_

- [x] 3.1 Implement SessionScreen with StreamBuilder
  - File: `lib/src/screens/session_screen.dart`
  - Create SessionScreen connecting to device and displaying HR stream
  - Show BPM, zone indicator, and session controls
  - Purpose: Live HR monitoring during workouts
  - _Leverage: lib/src/bridge/api_generated.dart_
  - _Requirements: 3_
  - _Prompt: Role: Flutter async UI expert | Task: Create SessionScreen receiving device_id from route args. In initState, call api.connectDevice(deviceId), then api.createHrStream(). Use StreamBuilder<FilteredHeartRate> to rebuild on data. Display filtered_bpm as Text style: TextStyle(fontSize: 72), zone as colored Container. Add FloatingActionButton "Start Workout" | Restrictions: Must dispose stream in dispose() | Success: UI updates reactively with HR data_

- [x] 3.2 Create HR display widgets
  - File: `lib/src/widgets/hr_display.dart`, `lib/src/widgets/zone_indicator.dart`
  - Extract reusable widgets for BPM and zone visualization
  - Purpose: Modular UI components
  - _Leverage: Material Design 3 colors_
  - _Requirements: 3_
  - _Prompt: Role: Flutter widget developer | Task: Create HrDisplay widget taking bpm as int, displaying large centered text. Create ZoneIndicator taking Zone enum, showing colored bar (Zone1: blue, Zone2: green, Zone3: yellow, Zone4: orange, Zone5: red). Add battery indicator icon when battery < 20% | Restrictions: StatelessWidget, no business logic | Success: Widgets reusable and themed_

- [x] 4.1 Implement SettingsScreen
  - File: `lib/src/screens/settings_screen.dart`
  - Create SettingsScreen with max_hr TextField
  - Persist to SharedPreferences
  - Purpose: User configuration
  - _Leverage: shared_preferences package_
  - _Requirements: 4_
  - _Prompt: Role: Flutter forms developer | Task: Create SettingsScreen with TextField "Max Heart Rate" (default 180), TextInputType.number. On save, write to SharedPreferences key 'max_hr'. Load value in initState. Add Form validation (100-220 range) | Restrictions: Must validate input before saving | Success: Max HR persists across app restarts_

- [x] 5.1 Implement background service
  - File: `lib/src/services/background_service.dart`
  - Set up Android Foreground Service for session continuity
  - Purpose: Keep HR streaming when screen locked
  - _Leverage: flutter_background_service_
  - _Requirements: 5_
  - _Prompt: Role: Flutter platform specialist | Task: Create BackgroundService class using flutter_background_service. On startService(), create foreground notification showing "Heart Rate: [bpm]". Update notification text when HR data arrives. On stopService(), cancel notification. Add Android manifest permissions FOREGROUND_SERVICE, WAKE_LOCK | Restrictions: Foreground service only, not background processing | Success: Service keeps app alive during workouts_

- [x] 5.2 Update AndroidManifest.xml
  - File: `android/app/src/main/AndroidManifest.xml`
  - Add Bluetooth, location, and foreground service permissions
  - Purpose: Enable BLE and background operation
  - _Leverage: Android API 26+ permission model_
  - _Requirements: 5_
  - _Prompt: Role: Android configuration expert | Task: Add <uses-permission> for BLUETOOTH, BLUETOOTH_ADMIN, BLUETOOTH_SCAN, BLUETOOTH_CONNECT, ACCESS_FINE_LOCATION, FOREGROUND_SERVICE. Add <service android:name=".ForegroundService" android:foregroundServiceType="location" />. Set minSdkVersion 26 | Restrictions: Follow Android 12+ permission requirements | Success: App requests permissions correctly on Android 12+_

- [x] 6.1 Add integration tests
  - File: `integration_test/app_test.dart`
  - Write Patrol E2E test: launch app, scan, connect, verify HR stream
  - Purpose: Automated UI testing
  - _Leverage: patrol package_
  - _Requirements: All_
  - _Prompt: Role: Flutter test automation engineer | Task: Create app_test.dart using Patrol. Test: launch app, tap "Scan for Devices", grant permissions, tap first device, verify SessionScreen shows, verify BPM updates. Use patrol tester for native permissions. Mock BLE adapter in test mode | Restrictions: Must use Mock BLE for CI, not require real device | Success: Test passes in CI with mock adapter_
