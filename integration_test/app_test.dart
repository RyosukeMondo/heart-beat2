import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/main.dart' as app;
import 'package:patrol/patrol.dart';

void main() {
  patrolTest(
    'Heart Beat E2E flow: scan, connect, verify HR stream',
    ($) async {
      // Launch the app
      await app.main();
      await $.pumpAndSettle();

      // Verify home screen loads
      expect($(const Key('homeScreen')), findsOneWidget);
      expect(find.text('Scan for Devices'), findsOneWidget);

      // Navigate to settings via AppBar icon
      await $(Icons.settings).tap();
      await $.pumpAndSettle();

      // Verify settings screen shows
      expect($(const Key('settingsScreen')), findsOneWidget);

      // Go back to home screen
      await $.native.pressBack();
      await $.pumpAndSettle();

      // Tap scan button
      await $(find.text('Scan for Devices')).tap();

      // Grant Bluetooth permissions using native automation
      // Note: In CI/mock mode, permissions should be auto-granted
      if (await $.native.isPermissionDialogVisible()) {
        await $.native.grantPermissionWhenInUse();
      }

      await $.pumpAndSettle(timeout: const Duration(seconds: 5));

      // Wait for scan to complete
      // In mock mode, scanDevices() should return mock devices
      await $.waitUntilVisible(find.byType(ListTile), timeout: const Duration(seconds: 10));

      // Tap first device to connect
      await $(find.byType(ListTile).first).tap();
      await $.pumpAndSettle();

      // Verify session screen loads
      expect($(const Key('sessionScreen')), findsOneWidget);

      // Wait for connection to establish
      await $.waitUntilVisible(find.text('Start Workout'), timeout: const Duration(seconds: 10));

      // Verify HR display components are visible
      expect($(const Key('hrDisplay')), findsOneWidget);
      expect($(const Key('zoneIndicator')), findsOneWidget);

      // Verify "Start Workout" FAB is present
      expect(find.text('Start Workout'), findsOneWidget);

      // Test start workout button (currently shows snackbar)
      await $(find.text('Start Workout')).tap();
      await $.pumpAndSettle();

      // Verify snackbar appears
      expect(find.text('Start Workout - Coming Soon'), findsOneWidget);
    },
  );

  patrolTest(
    'Settings: max heart rate persistence',
    ($) async {
      // Launch the app
      await app.main();
      await $.pumpAndSettle();

      // Navigate to settings
      await $(Icons.settings).tap();
      await $.pumpAndSettle();

      // Verify default max HR is shown (or previously saved value)
      expect($(const Key('settingsScreen')), findsOneWidget);

      // Find and tap the max HR text field
      await $(const Key('maxHrField')).enterText('190');
      await $.pumpAndSettle();

      // Tap save button
      await $(find.text('Save Settings')).tap();
      await $.pumpAndSettle();

      // Verify success message
      expect(find.text('Settings saved successfully'), findsOneWidget);

      // Navigate away and back to verify persistence
      await $.native.pressBack();
      await $.pumpAndSettle();

      await $(Icons.settings).tap();
      await $.pumpAndSettle();

      // Verify the value persisted
      expect(find.text('190'), findsOneWidget);
    },
  );

  patrolTest(
    'Permission denial handling',
    ($) async {
      // Launch the app
      await app.main();
      await $.pumpAndSettle();

      // Tap scan button
      await $(find.text('Scan for Devices')).tap();

      // Deny permissions if dialog appears
      if (await $.native.isPermissionDialogVisible()) {
        await $.native.denyPermission();
      }

      await $.pumpAndSettle(timeout: const Duration(seconds: 3));

      // Verify error snackbar appears
      expect(
        find.text('Bluetooth permissions denied. Please enable them in settings.'),
        findsOneWidget,
      );
    },
  );
}
