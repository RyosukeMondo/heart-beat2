import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/main.dart' as app;
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'package:patrol/patrol.dart';

/// Test helpers and utilities for integration tests.
///
/// This file provides reusable utilities for integration tests including:
/// - Mock BLE device simulation setup
/// - App launch utilities
/// - Permission handling helpers
/// - Common test patterns and assertions
/// - Device connection helpers
/// - Navigation helpers

/// Launches the Heart Beat app and waits for it to settle.
///
/// This is the standard way to launch the app in integration tests.
/// It calls app.main() and waits for animations to complete.
///
/// Example:
/// ```dart
/// await launchApp($);
/// ```
Future<void> launchApp(PatrolIntegrationTester $) async {
  await app.main();
  await $.pumpAndSettle();
}

/// Starts mock mode for testing without real BLE hardware.
///
/// This enables the mock BLE adapter which generates simulated heart rate data.
/// Should be called before any BLE operations in tests that don't use real devices.
///
/// Example:
/// ```dart
/// await startMockMode();
/// await launchApp($);
/// ```
Future<void> startMockMode() async {
  await startMockMode();
}

/// Grants Bluetooth permissions if a permission dialog is visible.
///
/// This helper checks if a native permission dialog is showing and grants
/// the permission if present. Safe to call even if no dialog is visible.
///
/// Example:
/// ```dart
/// await tapScanButton($);
/// await grantBluetoothPermissionsIfNeeded($);
/// ```
Future<void> grantBluetoothPermissionsIfNeeded(
  PatrolIntegrationTester $,
) async {
  if (await $.native.isPermissionDialogVisible()) {
    await $.native.grantPermissionWhenInUse();
  }
  await $.pumpAndSettle();
}

/// Denies Bluetooth permissions if a permission dialog is visible.
///
/// This helper checks if a native permission dialog is showing and denies
/// the permission if present. Useful for testing error handling.
///
/// Example:
/// ```dart
/// await tapScanButton($);
/// await denyBluetoothPermissionsIfNeeded($);
/// await expectSnackbarWithText($, 'Bluetooth permissions denied');
/// ```
Future<void> denyBluetoothPermissionsIfNeeded(
  PatrolIntegrationTester $,
) async {
  if (await $.native.isPermissionDialogVisible()) {
    await $.native.denyPermission();
  }
  await $.pumpAndSettle();
}

/// Navigates to the settings screen via the AppBar icon.
///
/// Example:
/// ```dart
/// await launchApp($);
/// await navigateToSettings($);
/// expect($(const Key('settingsScreen')), findsOneWidget);
/// ```
Future<void> navigateToSettings(PatrolIntegrationTester $) async {
  await $(Icons.settings).tap();
  await $.pumpAndSettle();
}

/// Navigates back using the native back button.
///
/// Example:
/// ```dart
/// await navigateToSettings($);
/// await navigateBack($);
/// expect($(const Key('homeScreen')), findsOneWidget);
/// ```
Future<void> navigateBack(PatrolIntegrationTester $) async {
  await $.native.pressBack();
  await $.pumpAndSettle();
}

/// Taps the "Scan for Devices" button on the home screen.
///
/// Example:
/// ```dart
/// await launchApp($);
/// await tapScanButton($);
/// await grantBluetoothPermissionsIfNeeded($);
/// ```
Future<void> tapScanButton(PatrolIntegrationTester $) async {
  await $(find.text('Scan for Devices')).tap();
  await $.pumpAndSettle();
}

/// Waits for devices to appear in the scan results list.
///
/// Waits up to 10 seconds for at least one device to appear as a ListTile.
/// Throws if no devices are found within the timeout.
///
/// Example:
/// ```dart
/// await tapScanButton($);
/// await grantBluetoothPermissionsIfNeeded($);
/// await waitForDevices($);
/// ```
Future<void> waitForDevices(
  PatrolIntegrationTester $, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  await $.waitUntilVisible(find.byType(ListTile), timeout: timeout);
}

/// Connects to the first device in the scan results.
///
/// Taps the first ListTile (device) and waits for the session screen to load.
/// Assumes at least one device is present in the scan results.
///
/// Example:
/// ```dart
/// await waitForDevices($);
/// await connectToFirstDevice($);
/// expect($(const Key('sessionScreen')), findsOneWidget);
/// ```
Future<void> connectToFirstDevice(PatrolIntegrationTester $) async {
  await $(find.byType(ListTile).first).tap();
  await $.pumpAndSettle();
}

/// Waits for the session screen to be ready with HR display.
///
/// Waits for the "Start Workout" button to appear, indicating the device
/// is connected and streaming HR data.
///
/// Example:
/// ```dart
/// await connectToFirstDevice($);
/// await waitForSessionReady($);
/// expect($(const Key('hrDisplay')), findsOneWidget);
/// ```
Future<void> waitForSessionReady(
  PatrolIntegrationTester $, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  await $.waitUntilVisible(find.text('Start Workout'), timeout: timeout);
}

/// Taps the "Start Workout" button on the session screen.
///
/// Example:
/// ```dart
/// await waitForSessionReady($);
/// await tapStartWorkout($);
/// ```
Future<void> tapStartWorkout(PatrolIntegrationTester $) async {
  await $(find.text('Start Workout')).tap();
  await $.pumpAndSettle();
}

/// Expects a snackbar with the given text to be visible.
///
/// Example:
/// ```dart
/// await tapStartWorkout($);
/// await expectSnackbarWithText($, 'Start Workout - Coming Soon');
/// ```
void expectSnackbarWithText(PatrolIntegrationTester $, String text) {
  expect(find.text(text), findsOneWidget);
}

/// Waits for a widget with the given key to appear.
///
/// Example:
/// ```dart
/// await connectToFirstDevice($);
/// await waitForKey($, const Key('sessionScreen'));
/// ```
Future<void> waitForKey(
  PatrolIntegrationTester $,
  Key key, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  await $.waitUntilVisible(find.byKey(key), timeout: timeout);
}

/// Waits for text to appear.
///
/// Example:
/// ```dart
/// await waitForText($, 'Connected');
/// ```
Future<void> waitForText(
  PatrolIntegrationTester $,
  String text, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  await $.waitUntilVisible(find.text(text), timeout: timeout);
}

/// Expects a screen with the given key to be visible.
///
/// Example:
/// ```dart
/// await launchApp($);
/// expectScreen($, const Key('homeScreen'));
/// ```
void expectScreen(PatrolIntegrationTester $, Key key) {
  expect($(key), findsOneWidget);
}

/// Simulates a full device connection flow.
///
/// This is a high-level helper that performs:
/// 1. Launch app
/// 2. Tap scan button
/// 3. Grant permissions
/// 4. Wait for devices
/// 5. Connect to first device
/// 6. Wait for session screen
///
/// Example:
/// ```dart
/// await performDeviceConnection($);
/// expect($(const Key('sessionScreen')), findsOneWidget);
/// ```
Future<void> performDeviceConnection(PatrolIntegrationTester $) async {
  await launchApp($);
  await tapScanButton($);
  await grantBluetoothPermissionsIfNeeded($);
  await waitForDevices($);
  await connectToFirstDevice($);
  await waitForSessionReady($);
}

/// Enters text into a text field with the given key.
///
/// Example:
/// ```dart
/// await navigateToSettings($);
/// await enterTextInField($, const Key('maxHrField'), '190');
/// ```
Future<void> enterTextInField(
  PatrolIntegrationTester $,
  Key key,
  String text,
) async {
  await $(key).enterText(text);
  await $.pumpAndSettle();
}

/// Taps a button with the given text.
///
/// Example:
/// ```dart
/// await tapButtonWithText($, 'Save Settings');
/// ```
Future<void> tapButtonWithText(
  PatrolIntegrationTester $,
  String text,
) async {
  await $(find.text(text)).tap();
  await $.pumpAndSettle();
}

/// Taps a button with the given key.
///
/// Example:
/// ```dart
/// await tapButtonWithKey($, const Key('saveButton'));
/// ```
Future<void> tapButtonWithKey(PatrolIntegrationTester $, Key key) async {
  await $(key).tap();
  await $.pumpAndSettle();
}

/// Expects a widget with the given key to be visible.
///
/// Example:
/// ```dart
/// expectWidgetWithKey($, const Key('hrDisplay'));
/// ```
void expectWidgetWithKey(PatrolIntegrationTester $, Key key) {
  expect($(key), findsOneWidget);
}

/// Expects a widget with the given key to not be visible.
///
/// Example:
/// ```dart
/// expectNoWidgetWithKey($, const Key('loadingSpinner'));
/// ```
void expectNoWidgetWithKey(PatrolIntegrationTester $, Key key) {
  expect($(key), findsNothing);
}

/// Waits for a specific duration.
///
/// Use sparingly - prefer waitUntilVisible or waitForKey when possible.
///
/// Example:
/// ```dart
/// await wait($, const Duration(seconds: 2));
/// ```
Future<void> wait(
  PatrolIntegrationTester $,
  Duration duration,
) async {
  await Future.delayed(duration);
  await $.pumpAndSettle();
}

/// Scrolls until a widget with the given finder is visible.
///
/// Example:
/// ```dart
/// await scrollUntilVisible($, find.text('Advanced Settings'));
/// ```
Future<void> scrollUntilVisible(
  PatrolIntegrationTester $,
  Finder finder, {
  Finder? scrollable,
}) async {
  await $.scrollUntilVisible(
    finder: finder,
    view: scrollable ?? find.byType(Scrollable).first,
  );
  await $.pumpAndSettle();
}

/// Mock device configuration for tests.
///
/// Use this to configure mock device behavior for different test scenarios.
class MockDeviceConfig {
  /// Device name that will appear in scan results
  final String name;

  /// Device ID (typically MAC address or UUID)
  final String id;

  /// RSSI (signal strength) value
  final int rssi;

  /// Whether connection should succeed
  final bool shouldConnectSuccessfully;

  /// Initial heart rate value
  final int initialHeartRate;

  /// Whether to simulate battery data
  final bool hasBattery;

  /// Initial battery level (0-100)
  final int initialBatteryLevel;

  const MockDeviceConfig({
    this.name = 'Mock HRM',
    this.id = '00:00:00:00:00:00',
    this.rssi = -60,
    this.shouldConnectSuccessfully = true,
    this.initialHeartRate = 75,
    this.hasBattery = true,
    this.initialBatteryLevel = 85,
  });

  /// Default mock device configuration
  static const MockDeviceConfig defaultDevice = MockDeviceConfig();

  /// Mock device with weak signal
  static const MockDeviceConfig weakSignal = MockDeviceConfig(
    name: 'Weak Signal HRM',
    rssi: -90,
  );

  /// Mock device that fails to connect
  static const MockDeviceConfig failsConnection = MockDeviceConfig(
    name: 'Failing HRM',
    shouldConnectSuccessfully: false,
  );

  /// Mock device with low battery
  static const MockDeviceConfig lowBattery = MockDeviceConfig(
    name: 'Low Battery HRM',
    initialBatteryLevel: 10,
  );
}

/// Pattern for testing with mock BLE devices.
///
/// This pattern ensures consistent setup and teardown for tests using mock mode.
///
/// Example:
/// ```dart
/// patrolTest('test name', ($) async {
///   await testWithMockDevice($, () async {
///     // Your test code here
///   });
/// });
/// ```
Future<void> testWithMockDevice(
  PatrolIntegrationTester $,
  Future<void> Function() testFn, {
  MockDeviceConfig config = MockDeviceConfig.defaultDevice,
}) async {
  // Start mock mode
  await startMockMode();

  try {
    // Run the test
    await testFn();
  } finally {
    // Cleanup: disconnect if connected
    try {
      await disconnect();
    } catch (e) {
      // Ignore disconnect errors in cleanup
    }
  }
}

/// Verifies the home screen is visible.
///
/// Example:
/// ```dart
/// await launchApp($);
/// verifyHomeScreen($);
/// ```
void verifyHomeScreen(PatrolIntegrationTester $) {
  expect($(const Key('homeScreen')), findsOneWidget);
  expect(find.text('Scan for Devices'), findsOneWidget);
}

/// Verifies the session screen is visible with HR display.
///
/// Example:
/// ```dart
/// await connectToFirstDevice($);
/// verifySessionScreen($);
/// ```
void verifySessionScreen(PatrolIntegrationTester $) {
  expect($(const Key('sessionScreen')), findsOneWidget);
  expect($(const Key('hrDisplay')), findsOneWidget);
  expect($(const Key('zoneIndicator')), findsOneWidget);
}

/// Verifies the settings screen is visible.
///
/// Example:
/// ```dart
/// await navigateToSettings($);
/// verifySettingsScreen($);
/// ```
void verifySettingsScreen(PatrolIntegrationTester $) {
  expect($(const Key('settingsScreen')), findsOneWidget);
}

/// Verifies the workout screen is visible.
///
/// Example:
/// ```dart
/// await startWorkout($);
/// verifyWorkoutScreen($);
/// ```
void verifyWorkoutScreen(PatrolIntegrationTester $) {
  expect($(const Key('workoutScreen')), findsOneWidget);
}

/// Navigates to the history screen via the AppBar icon.
///
/// Example:
/// ```dart
/// await launchApp($);
/// await navigateToHistory($);
/// expect($(const Key('historyScreen')), findsOneWidget);
/// ```
Future<void> navigateToHistory(PatrolIntegrationTester $) async {
  await $(Icons.history).tap();
  await $.pumpAndSettle();
}

/// Verifies the history screen is visible.
///
/// Example:
/// ```dart
/// await navigateToHistory($);
/// verifyHistoryScreen($);
/// ```
void verifyHistoryScreen(PatrolIntegrationTester $) {
  expect($(const Key('historyScreen')), findsOneWidget);
}
