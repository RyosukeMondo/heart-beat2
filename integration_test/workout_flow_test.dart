import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_helpers.dart';

/// Integration tests for the workout start flow.
///
/// These tests verify the complete workout initiation flow:
/// - Starting from session screen
/// - Tapping "Start Workout" button
/// - Plan selector bottom sheet appearance
/// - Plan selection
/// - Navigation to workout screen
///
/// This is a regression test for the PlanSelector navigation bug where
/// the onSelect callback wasn't properly navigating to the workout screen.
void main() {
  patrolTest(
    'Start workout flow - tap Start Workout and select plan',
    ($) async {
      // Perform full device connection to reach session screen
      await performDeviceConnection($);

      // Verify we're on session screen
      verifySessionScreen($);

      // Verify Start Workout button is present
      expect(find.text('Start Workout'), findsOneWidget);

      // Tap Start Workout button
      await tapStartWorkout($);

      // Wait for plan selector to appear
      await waitForText($, 'Select Training Plan', timeout: const Duration(seconds: 5));

      // Verify plan selector title is visible
      expect(find.text('Select Training Plan'), findsOneWidget);

      // Verify plan selector icon is visible
      expect(find.byIcon(Icons.fitness_center), findsOneWidget);

      // Wait for plans to load (they should appear as ListTiles)
      await $.waitUntilVisible(
        find.byType(ListTile),
        timeout: const Duration(seconds: 5),
      );

      // Verify at least one plan is available
      expect(find.byType(ListTile), findsAtLeastNWidgets(1));

      // Select the first plan
      await $(find.byType(ListTile).first).tap();
      await $.pumpAndSettle();

      // Verify navigation to workout screen occurred
      await waitForKey($, const Key('workoutScreen'), timeout: const Duration(seconds: 10));
      expectScreen($, const Key('workoutScreen'));

      // Verify we're no longer on session screen
      expectNoWidgetWithKey($, const Key('sessionScreen'));

      // Verify workout screen is showing (has plan name in title or showing workout content)
      // The workout should be starting or already started
      final startingWorkout = find.text('Starting workout...');
      final hasStartingText = $(startingWorkout).exists;

      if (!hasStartingText) {
        // If not starting anymore, workout should be active
        // Verify phase progress indicator exists (from workout_screen.dart)
        expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
      }
    },
  );

  patrolTest(
    'Start workout flow - verify plan selector can be dismissed',
    ($) async {
      // Perform full device connection to reach session screen
      await performDeviceConnection($);

      // Tap Start Workout button
      await tapStartWorkout($);

      // Wait for plan selector to appear
      await waitForText($, 'Select Training Plan');

      // Verify plan selector is visible
      expect(find.text('Select Training Plan'), findsOneWidget);

      // Dismiss the bottom sheet by pressing back
      await navigateBack($);

      // Verify we're back on session screen (plan selector is gone)
      verifySessionScreen($);
      expect(find.text('Select Training Plan'), findsNothing);

      // Verify we can open plan selector again
      await tapStartWorkout($);
      await waitForText($, 'Select Training Plan');
      expect(find.text('Select Training Plan'), findsOneWidget);
    },
  );

  patrolTest(
    'Start workout flow - multiple plans visible in selector',
    ($) async {
      // Perform full device connection
      await performDeviceConnection($);

      // Open plan selector
      await tapStartWorkout($);
      await waitForText($, 'Select Training Plan');

      // Wait for plans to load
      await $.waitUntilVisible(find.byType(ListTile));

      // Verify each plan tile has the expected components
      final planTiles = find.byType(ListTile);
      expect(planTiles, findsAtLeastNWidgets(1));

      // Verify first plan has icon and arrow
      expect(find.byIcon(Icons.directions_run), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.arrow_forward_ios), findsAtLeastNWidgets(1));

      // Verify CircleAvatar is used for plan icon
      expect(find.byType(CircleAvatar), findsAtLeastNWidgets(1));
    },
  );

  patrolTest(
    'Start workout flow - plan selector shows loading state',
    ($) async {
      // Perform full device connection
      await performDeviceConnection($);

      // Open plan selector
      await tapStartWorkout($);

      // Plan selector should appear quickly
      await waitForText($, 'Select Training Plan', timeout: const Duration(seconds: 3));

      // There might be a brief loading state, but plans should load quickly
      // We just verify the final state has plans
      await $.waitUntilVisible(
        find.byType(ListTile),
        timeout: const Duration(seconds: 5),
      );

      expect(find.byType(ListTile), findsAtLeastNWidgets(1));
    },
  );

  patrolTest(
    'Start workout flow - verify workout screen starts workout',
    ($) async {
      // Perform connection and navigate to workout
      await performDeviceConnection($);
      await tapStartWorkout($);
      await waitForText($, 'Select Training Plan');
      await $.waitUntilVisible(find.byType(ListTile));
      await $(find.byType(ListTile).first).tap();
      await $.pumpAndSettle();

      // Wait for workout screen
      await waitForKey($, const Key('workoutScreen'));

      // Workout should be starting or started
      // Wait a bit for workout to initialize
      await wait($, const Duration(seconds: 2));

      // After initialization, workout should show either:
      // - Starting state with loading indicator
      // - Active workout with progress
      final hasLoadingIndicator = find.byType(CircularProgressIndicator);
      final loadingExists = $(hasLoadingIndicator).exists;

      // Workout screen should be present
      expectScreen($, const Key('workoutScreen'));

      // Some UI should be present (either loading or workout content)
      expect(
        loadingExists || find.byType(AppBar).evaluate().isNotEmpty,
        isTrue,
      );
    },
  );

  patrolTest(
    'Start workout flow - back navigation from workout to session',
    ($) async {
      // Perform full flow to workout screen
      await performDeviceConnection($);
      await tapStartWorkout($);
      await waitForText($, 'Select Training Plan');
      await $.waitUntilVisible(find.byType(ListTile));
      await $(find.byType(ListTile).first).tap();
      await $.pumpAndSettle();

      // Wait for workout screen
      await waitForKey($, const Key('workoutScreen'));

      // Navigate back
      await navigateBack($);

      // Should be back on session screen
      verifySessionScreen($);
      expectNoWidgetWithKey($, const Key('workoutScreen'));
    },
  );

  patrolTest(
    'Regression test - PlanSelector navigation bug is fixed',
    ($) async {
      // This test specifically validates that the bug where PlanSelector.onSelect
      // wasn't navigating to WorkoutScreen is fixed.
      //
      // The bug was in session_screen.dart where Navigator.of(context) was used
      // instead of Navigator.of(context, rootNavigator: true), causing navigation
      // to fail because the context was inside the modal bottom sheet.

      await performDeviceConnection($);

      // Verify starting point
      expectScreen($, const Key('sessionScreen'));

      // Open plan selector
      await tapStartWorkout($);
      await waitForText($, 'Select Training Plan');

      // Select a plan
      await $.waitUntilVisible(find.byType(ListTile));
      await $(find.byType(ListTile).first).tap();
      await $.pumpAndSettle();

      // CRITICAL: Verify navigation actually occurred
      // This is what was broken - the navigation would fail silently
      await waitForKey($, const Key('workoutScreen'), timeout: const Duration(seconds: 10));
      expectScreen($, const Key('workoutScreen'));

      // Verify we left the session screen
      expectNoWidgetWithKey($, const Key('sessionScreen'));

      // Verify we're not stuck with the plan selector visible
      expect(find.text('Select Training Plan'), findsNothing);
    },
  );
}
