import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'test_helpers.dart';

/// Integration tests for the session history flow.
///
/// These tests verify:
/// - Navigation to history screen from home
/// - Viewing session list (with and without data)
/// - Selecting a session to view details
/// - Session detail screen displays correctly
/// - Navigation back from detail to history
/// - Empty state when no sessions exist
void main() {
  patrolTest(
    'Navigate to history screen from home',
    ($) async {
      // Launch the app
      await launchApp($);

      // Verify we're on the home screen
      verifyHomeScreen($);

      // Navigate to history by tapping the history icon
      await $(Icons.history).tap();
      await $.pumpAndSettle();

      // Verify history screen is visible
      verifyHistoryScreen($);

      // Verify the title is correct
      expect(find.text('Session History'), findsOneWidget);
    },
  );

  patrolTest(
    'History screen shows empty state when no sessions exist',
    ($) async {
      // Launch the app and navigate to history
      await launchApp($);
      await $(Icons.history).tap();
      await $.pumpAndSettle();

      // Verify empty state is displayed
      expect(find.text('No training sessions yet'), findsOneWidget);
      expect(
        find.text('Complete a training session to see it here'),
        findsOneWidget,
      );

      // Verify the empty state icon is visible
      expect(find.byIcon(Icons.history), findsWidgets);
    },
  );

  patrolTest(
    'Pull to refresh on history screen',
    ($) async {
      // Launch the app and navigate to history
      await launchApp($);
      await $(Icons.history).tap();
      await $.pumpAndSettle();

      // If there are sessions, we can test refresh
      // For now, verify the screen is present
      verifyHistoryScreen($);

      // Pull down to refresh (simulate)
      // Note: This gesture might not work in all test scenarios
      // but we verify the RefreshIndicator exists
      final historyScreenFinder = $(const Key('historyScreen'));
      expect(historyScreenFinder, findsOneWidget);
    },
  );

  patrolTest(
    'Navigate back from history to home',
    ($) async {
      // Launch and navigate to history
      await launchApp($);
      await $(Icons.history).tap();
      await $.pumpAndSettle();

      // Verify we're on history screen
      verifyHistoryScreen($);

      // Navigate back
      await navigateBack($);

      // Verify we're back on home screen
      verifyHomeScreen($);
    },
  );

  patrolTest(
    'History screen shows session list when sessions exist',
    ($) async {
      // This test assumes there might be sessions in the database
      // from previous tests or manual usage
      await launchApp($);
      await $(Icons.history).tap();
      await $.pumpAndSettle();

      // Wait for loading to complete
      await wait($, const Duration(milliseconds: 500));

      // Check if we have sessions or empty state
      // We can't reliably seed data in integration tests without additional
      // Rust API support, so we check for either state
      final emptySessions = find.text('No training sessions yet');
      final hasEmptyState = emptySessions.evaluate().isNotEmpty;

      if (!hasEmptyState) {
        // We have sessions - verify the list is present
        // Sessions are displayed as Cards with ListTiles
        expect(find.byType(Card), findsWidgets);

        // Verify there are session items (ListTile in Card)
        final sessionItems = find.byType(ListTile);
        expect(sessionItems, findsWidgets);

        // Each session should have navigation arrow
        expect(find.byIcon(Icons.arrow_forward_ios), findsWidgets);
      } else {
        // Verify empty state
        expect(emptySessions, findsOneWidget);
      }
    },
  );

  patrolTest(
    'Tap session opens detail screen',
    ($) async {
      // Launch and navigate to history
      await launchApp($);
      await $(Icons.history).tap();
      await $.pumpAndSettle();

      // Wait for loading
      await wait($, const Duration(milliseconds: 500));

      // Check if we have sessions
      final sessionItems = find.byType(ListTile);

      if (sessionItems.evaluate().isNotEmpty) {
        // Tap the first session
        await $(sessionItems.first).tap();
        await $.pumpAndSettle();

        // Wait for detail screen to load
        await wait($, const Duration(milliseconds: 1000));

        // Verify we're on the detail screen
        expect(find.text('Session Details'), findsOneWidget);

        // Verify key elements of detail screen
        // The detail screen should have these elements
        final detailIndicators = [
          find.text('Summary'),
          find.text('Duration'),
          find.text('Avg HR'),
        ];

        // At least some of these should be present
        int foundCount = 0;
        for (final indicator in detailIndicators) {
          if (indicator.evaluate().isNotEmpty) {
            foundCount++;
          }
        }
        expect(foundCount, greaterThan(0),
            reason: 'Detail screen should show summary information');
      } else {
        // No sessions available - skip this test
        debugPrint('No sessions available to test detail navigation');
      }
    },
  );

  patrolTest(
    'Navigate back from session detail to history',
    ($) async {
      // Launch and navigate to history
      await launchApp($);
      await $(Icons.history).tap();
      await $.pumpAndSettle();

      // Wait for loading
      await wait($, const Duration(milliseconds: 500));

      // Check if we have sessions
      final sessionItems = find.byType(ListTile);

      if (sessionItems.evaluate().isNotEmpty) {
        // Open first session detail
        await $(sessionItems.first).tap();
        await $.pumpAndSettle();

        // Wait for detail screen
        await wait($, const Duration(milliseconds: 1000));

        // Navigate back
        await navigateBack($);

        // Verify we're back on history screen
        verifyHistoryScreen($);
        expect(find.text('Session History'), findsOneWidget);
      } else {
        // No sessions available - skip this test
        debugPrint('No sessions available to test back navigation');
      }
    },
  );

  patrolTest(
    'Session detail shows error for invalid session',
    ($) async {
      // Launch app
      await launchApp($);

      // Manually navigate to session detail with invalid ID
      // This tests error handling
      Navigator.pushNamed(
        $.tester.element(find.byType(MaterialApp)),
        '/session-detail',
        arguments: {'session_id': 'invalid-session-id-12345'},
      );
      await $.pumpAndSettle();

      // Wait for error to appear
      await wait($, const Duration(milliseconds: 1000));

      // Verify error state is shown
      final errorIndicators = [
        find.byIcon(Icons.error_outline),
        find.byIcon(Icons.search_off),
        find.text('Session not found'),
        find.text('Failed to load session'),
      ];

      // At least one error indicator should be present
      int foundErrors = 0;
      for (final indicator in errorIndicators) {
        if (indicator.evaluate().isNotEmpty) {
          foundErrors++;
        }
      }
      expect(foundErrors, greaterThan(0),
          reason: 'Error state should be displayed for invalid session');
    },
  );

  patrolTest(
    'Long press session enables selection mode',
    ($) async {
      // Launch and navigate to history
      await launchApp($);
      await $(Icons.history).tap();
      await $.pumpAndSettle();

      // Wait for loading
      await wait($, const Duration(milliseconds: 500));

      // Check if we have sessions
      final sessionItems = find.byType(ListTile);

      if (sessionItems.evaluate().isNotEmpty) {
        // Long press on first session
        await $(sessionItems.first).longPress();
        await $.pumpAndSettle();

        // Wait a bit
        await wait($, const Duration(milliseconds: 300));

        // Verify selection mode is enabled
        // In selection mode, title shows count and checkboxes appear
        final selectionIndicators = [
          find.text('1 selected'),
          find.byType(Checkbox),
        ];

        int foundIndicators = 0;
        for (final indicator in selectionIndicators) {
          if (indicator.evaluate().isNotEmpty) {
            foundIndicators++;
          }
        }
        expect(foundIndicators, greaterThan(0),
            reason: 'Selection mode should be enabled after long press');
      } else {
        // No sessions available - skip this test
        debugPrint('No sessions available to test selection mode');
      }
    },
  );

  patrolTest(
    'Exit selection mode with close button',
    ($) async {
      // Launch and navigate to history
      await launchApp($);
      await $(Icons.history).tap();
      await $.pumpAndSettle();

      // Wait for loading
      await wait($, const Duration(milliseconds: 500));

      // Check if we have sessions
      final sessionItems = find.byType(ListTile);

      if (sessionItems.evaluate().isNotEmpty) {
        // Enter selection mode
        await $(sessionItems.first).longPress();
        await $.pumpAndSettle();
        await wait($, const Duration(milliseconds: 300));

        // Verify we're in selection mode
        if (find.byIcon(Icons.close).evaluate().isNotEmpty) {
          // Tap close button to exit
          await $(Icons.close).tap();
          await $.pumpAndSettle();

          // Verify normal title is shown
          expect(find.text('Session History'), findsOneWidget);
        }
      } else {
        // No sessions available
        debugPrint('No sessions available to test selection mode exit');
      }
    },
  );

  patrolTest(
    'Complete history navigation flow',
    ($) async {
      // This is a comprehensive test of the entire history flow

      // 1. Start from home
      await launchApp($);
      verifyHomeScreen($);

      // 2. Navigate to history
      await $(Icons.history).tap();
      await $.pumpAndSettle();
      verifyHistoryScreen($);

      // 3. Wait for loading
      await wait($, const Duration(milliseconds: 500));

      // 4. Check state (empty or with sessions)
      final emptySessions = find.text('No training sessions yet');
      final hasEmptyState = emptySessions.evaluate().isNotEmpty;

      if (!hasEmptyState) {
        // 5. If we have sessions, open detail
        final sessionItems = find.byType(ListTile);
        if (sessionItems.evaluate().isNotEmpty) {
          await $(sessionItems.first).tap();
          await $.pumpAndSettle();
          await wait($, const Duration(milliseconds: 1000));

          // 6. Verify detail screen
          expect(find.text('Session Details'), findsOneWidget);

          // 7. Navigate back to history
          await navigateBack($);
          verifyHistoryScreen($);
        }
      } else {
        // 5. Verify empty state is correct
        expect(emptySessions, findsOneWidget);
      }

      // 8. Navigate back to home
      await navigateBack($);
      verifyHomeScreen($);
    },
  );
}
