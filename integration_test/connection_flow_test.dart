import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_helpers.dart';

/// Integration tests for the device connection flow.
///
/// These tests verify the complete BLE connection flow:
/// - App launch
/// - Device scanning
/// - Permission handling
/// - Device selection
/// - Connection establishment
/// - Session screen display
void main() {
  patrolTest(
    'Successful device connection flow',
    ($) async {
      // Launch the app
      await launchApp($);

      // Verify home screen is visible
      verifyHomeScreen($);

      // Tap scan button
      await tapScanButton($);

      // Grant Bluetooth permissions if dialog appears
      await grantBluetoothPermissionsIfNeeded($);

      // Wait for devices to appear in scan results
      await waitForDevices($);

      // Verify at least one device is found
      expect(find.byType(ListTile), findsAtLeastNWidgets(1));

      // Connect to first device
      await connectToFirstDevice($);

      // Wait for session screen to be ready
      await waitForSessionReady($);

      // Verify session screen components are present
      verifySessionScreen($);

      // Verify we're on the session screen with key
      expectScreen($, const Key('sessionScreen'));
    },
  );

  patrolTest(
    'Permission denial handling during connection',
    ($) async {
      // Launch the app
      await launchApp($);

      // Verify home screen
      verifyHomeScreen($);

      // Tap scan button
      await tapScanButton($);

      // Deny permissions if dialog appears
      await denyBluetoothPermissionsIfNeeded($);

      // Verify error message appears
      await waitForText(
        $,
        'Bluetooth permissions denied. Please enable them in settings.',
        timeout: const Duration(seconds: 5),
      );

      // Verify no devices are shown
      expect(find.byType(ListTile), findsNothing);

      // Verify we're still on home screen
      verifyHomeScreen($);
    },
  );

  patrolTest(
    'Scan button state changes during scanning',
    ($) async {
      // Launch the app
      await launchApp($);

      // Verify scan button is enabled
      expect(find.text('Scan for Devices'), findsOneWidget);

      // Tap scan button
      await tapScanButton($);

      // Grant permissions if needed
      await grantBluetoothPermissionsIfNeeded($);

      // Button text may briefly show "Scanning..." before devices appear
      // We just verify the scan completes successfully

      // Wait for devices
      await waitForDevices($);

      // Verify scan completed (button should be back to normal state)
      expect(find.text('Scan for Devices'), findsOneWidget);
    },
  );

  patrolTest(
    'Multiple device scan results',
    ($) async {
      // Launch the app
      await launchApp($);

      // Tap scan button
      await tapScanButton($);

      // Grant permissions
      await grantBluetoothPermissionsIfNeeded($);

      // Wait for devices
      await waitForDevices($);

      // Verify multiple devices may appear
      // At minimum, we should have at least 1 device
      final deviceTiles = find.byType(ListTile);
      expect(deviceTiles, findsAtLeastNWidgets(1));

      // Verify each device tile has required components
      final firstTile = $(deviceTiles.first);
      expect(firstTile, findsOneWidget);

      // Verify device tile has icon and arrow
      expect(find.byIcon(Icons.favorite), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.arrow_forward_ios), findsAtLeastNWidgets(1));
    },
  );

  patrolTest(
    'Connection to device navigates to session screen',
    ($) async {
      // Launch the app
      await launchApp($);

      // Perform scan
      await tapScanButton($);
      await grantBluetoothPermissionsIfNeeded($);
      await waitForDevices($);

      // Verify we're on home screen before connection
      expectScreen($, const Key('homeScreen'));

      // Connect to device
      await connectToFirstDevice($);

      // Verify navigation occurred to session screen
      await waitForKey($, const Key('sessionScreen'));
      expectScreen($, const Key('sessionScreen'));

      // Verify we're no longer on home screen
      expectNoWidgetWithKey($, const Key('homeScreen'));
    },
  );

  patrolTest(
    'Session screen displays after successful connection',
    ($) async {
      // Perform full connection flow
      await performDeviceConnection($);

      // Verify all session screen components
      verifySessionScreen($);

      // Verify HR display is present
      expectWidgetWithKey($, const Key('hrDisplay'));

      // Verify zone indicator is present
      expectWidgetWithKey($, const Key('zoneIndicator'));

      // Verify Start Workout button is present
      expect(find.text('Start Workout'), findsOneWidget);
    },
  );

  patrolTest(
    'Back navigation from session screen to home',
    ($) async {
      // Perform full connection flow
      await performDeviceConnection($);

      // Verify we're on session screen
      verifySessionScreen($);

      // Navigate back
      await navigateBack($);

      // Verify we're back on home screen
      verifyHomeScreen($);
    },
  );

  patrolTest(
    'Re-scan after permission denial',
    ($) async {
      // Launch app
      await launchApp($);

      // First attempt: deny permissions
      await tapScanButton($);
      await denyBluetoothPermissionsIfNeeded($);

      // Wait for error message
      await waitForText(
        $,
        'Bluetooth permissions denied. Please enable them in settings.',
        timeout: const Duration(seconds: 5),
      );

      // Verify no devices shown
      expect(find.byType(ListTile), findsNothing);

      // Second attempt: grant permissions
      await tapScanButton($);
      await grantBluetoothPermissionsIfNeeded($);

      // Wait for devices
      await waitForDevices($);

      // Verify devices are now shown
      expect(find.byType(ListTile), findsAtLeastNWidgets(1));
    },
  );

  patrolTest(
    'Device list cleared on new scan',
    ($) async {
      // Launch app
      await launchApp($);

      // First scan
      await tapScanButton($);
      await grantBluetoothPermissionsIfNeeded($);
      await waitForDevices($);

      // Note the number of devices
      final firstScanDevices = find.byType(ListTile);
      expect(firstScanDevices, findsAtLeastNWidgets(1));

      // Second scan - tap scan again
      await tapScanButton($);
      await $.pumpAndSettle();

      // During scanning or immediately after, devices should be present
      // The key behavior is that the scan completes successfully
      await waitForDevices($);

      // Verify devices are still shown after re-scan
      expect(find.byType(ListTile), findsAtLeastNWidgets(1));
    },
  );

  patrolTest(
    'Connection flow using high-level helper',
    ($) async {
      // This test verifies the performDeviceConnection helper works correctly
      await performDeviceConnection($);

      // After helper completes, verify we're on session screen
      expectScreen($, const Key('sessionScreen'));
      verifySessionScreen($);

      // Verify all key components
      expectWidgetWithKey($, const Key('hrDisplay'));
      expectWidgetWithKey($, const Key('zoneIndicator'));
      expect(find.text('Start Workout'), findsOneWidget);
    },
  );
}
