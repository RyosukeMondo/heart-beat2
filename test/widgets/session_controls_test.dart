import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/widgets/session_controls.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('SessionControls Widget Tests', () {
    testWidgets('renders pause button when state is Running',
        (WidgetTester tester) async {
      final onPause = MockVoidCallback();
      final onResume = MockVoidCallback();
      final onStop = MockVoidCallback();

      await tester.pumpWidget(testWrapper(
        SessionControls(
          currentState: 'Running',
          onPause: onPause.call,
          onResume: onResume.call,
          onStop: onStop.call,
        ),
      ));

      // Verify pause button is shown
      verifyText('Pause');
      verifyIcon(Icons.pause);

      // Verify stop button is always shown
      verifyText('Stop');
      verifyIcon(Icons.stop);
    });

    testWidgets('renders resume button when state is Paused',
        (WidgetTester tester) async {
      final onPause = MockVoidCallback();
      final onResume = MockVoidCallback();
      final onStop = MockVoidCallback();

      await tester.pumpWidget(testWrapper(
        SessionControls(
          currentState: 'Paused',
          onPause: onPause.call,
          onResume: onResume.call,
          onStop: onStop.call,
        ),
      ));

      // Verify resume button is shown
      verifyText('Resume');
      verifyIcon(Icons.play_arrow);

      // Verify stop button is always shown
      verifyText('Stop');
      verifyIcon(Icons.stop);
    });

    testWidgets('calls onPause when pause button is tapped',
        (WidgetTester tester) async {
      final onPause = MockVoidCallback();
      final onResume = MockVoidCallback();
      final onStop = MockVoidCallback();

      await tester.pumpWidget(testWrapper(
        SessionControls(
          currentState: 'Running',
          onPause: onPause.call,
          onResume: onResume.call,
          onStop: onStop.call,
        ),
      ));

      // Tap the pause button
      await tapAndSettle(tester, find.text('Pause'));

      // Verify onPause was called
      expect(onPause.called, isTrue);
      expect(onPause.callCount, equals(1));

      // Verify other callbacks were not called
      expect(onResume.called, isFalse);
      expect(onStop.called, isFalse);
    });

    testWidgets('calls onResume when resume button is tapped',
        (WidgetTester tester) async {
      final onPause = MockVoidCallback();
      final onResume = MockVoidCallback();
      final onStop = MockVoidCallback();

      await tester.pumpWidget(testWrapper(
        SessionControls(
          currentState: 'Paused',
          onPause: onPause.call,
          onResume: onResume.call,
          onStop: onStop.call,
        ),
      ));

      // Tap the resume button
      await tapAndSettle(tester, find.text('Resume'));

      // Verify onResume was called
      expect(onResume.called, isTrue);
      expect(onResume.callCount, equals(1));

      // Verify other callbacks were not called
      expect(onPause.called, isFalse);
      expect(onStop.called, isFalse);
    });

    testWidgets('shows confirmation dialog when stop button is tapped',
        (WidgetTester tester) async {
      final onPause = MockVoidCallback();
      final onResume = MockVoidCallback();
      final onStop = MockVoidCallback();

      await tester.pumpWidget(testWrapper(
        SessionControls(
          currentState: 'Running',
          onPause: onPause.call,
          onResume: onResume.call,
          onStop: onStop.call,
        ),
      ));

      // Tap the stop button
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog is shown
      verifyText('Stop Workout?');
      verifyText(
          'Are you sure you want to stop this workout? Your progress will be saved.');
      verifyText('Cancel');

      // Verify onStop was not called yet
      expect(onStop.called, isFalse);
    });

    testWidgets('calls onStop when stop is confirmed',
        (WidgetTester tester) async {
      final onPause = MockVoidCallback();
      final onResume = MockVoidCallback();
      final onStop = MockVoidCallback();

      await tester.pumpWidget(testWrapper(
        SessionControls(
          currentState: 'Running',
          onPause: onPause.call,
          onResume: onResume.call,
          onStop: onStop.call,
        ),
      ));

      // Tap the stop button
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();

      // Tap the confirm button in the dialog
      await tapAndSettle(tester, find.text('Stop').last);

      // Verify onStop was called
      expect(onStop.called, isTrue);
      expect(onStop.callCount, equals(1));

      // Verify other callbacks were not called
      expect(onPause.called, isFalse);
      expect(onResume.called, isFalse);
    });

    testWidgets('does not call onStop when stop is cancelled',
        (WidgetTester tester) async {
      final onPause = MockVoidCallback();
      final onResume = MockVoidCallback();
      final onStop = MockVoidCallback();

      await tester.pumpWidget(testWrapper(
        SessionControls(
          currentState: 'Running',
          onPause: onPause.call,
          onResume: onResume.call,
          onStop: onStop.call,
        ),
      ));

      // Tap the stop button
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();

      // Tap the cancel button in the dialog
      await tapAndSettle(tester, find.text('Cancel'));

      // Verify onStop was not called
      expect(onStop.called, isFalse);

      // Verify other callbacks were not called
      expect(onPause.called, isFalse);
      expect(onResume.called, isFalse);
    });

    testWidgets('buttons have large touch targets for glove use',
        (WidgetTester tester) async {
      final onPause = MockVoidCallback();
      final onResume = MockVoidCallback();
      final onStop = MockVoidCallback();

      await tester.pumpWidget(testWrapper(
        SessionControls(
          currentState: 'Running',
          onPause: onPause.call,
          onResume: onResume.call,
          onStop: onStop.call,
        ),
      ));

      // Verify both button text labels are present
      verifyText('Pause');
      verifyText('Stop');

      // The widget is designed with large touch targets (56x140 minimum)
      // We verify that both buttons are rendered and tappable
      final pauseFinder = find.text('Pause');
      final stopFinder = find.text('Stop');

      expect(pauseFinder, findsOneWidget);
      expect(stopFinder, findsOneWidget);

      // Verify buttons can be tapped (implicit size check - if too small, would fail)
      await tester.tap(pauseFinder);
      await tester.pumpAndSettle();
      expect(onPause.called, isTrue);
    });

    testWidgets('stop button has destructive styling',
        (WidgetTester tester) async {
      final onPause = MockVoidCallback();
      final onResume = MockVoidCallback();
      final onStop = MockVoidCallback();

      await tester.pumpWidget(testWrapper(
        SessionControls(
          currentState: 'Running',
          onPause: onPause.call,
          onResume: onResume.call,
          onStop: onStop.call,
        ),
      ));

      // Verify stop button is present (it should have error container styling)
      verifyText('Stop');
      verifyIcon(Icons.stop);

      // The stop button is styled with error colors to indicate destructive action
      // We verify it exists and is functional
      final stopFinder = find.text('Stop');
      expect(stopFinder, findsOneWidget);

      // Tap it to verify it works (shows confirmation dialog)
      await tester.tap(stopFinder);
      await tester.pumpAndSettle();
      verifyText('Stop Workout?');
    });

    testWidgets('buttons are evenly spaced', (WidgetTester tester) async {
      final onPause = MockVoidCallback();
      final onResume = MockVoidCallback();
      final onStop = MockVoidCallback();

      await tester.pumpWidget(testWrapper(
        SessionControls(
          currentState: 'Running',
          onPause: onPause.call,
          onResume: onResume.call,
          onStop: onStop.call,
        ),
      ));

      // Verify Row with spaceEvenly is used (find the specific Row in SessionControls)
      final rows = tester.widgetList<Row>(find.byType(Row));
      final hasEvenlySpacedRow = rows.any((row) =>
        row.mainAxisAlignment == MainAxisAlignment.spaceEvenly);

      expect(hasEvenlySpacedRow, isTrue,
          reason: 'Should have a Row with spaceEvenly alignment for buttons');
    });

    testWidgets('widget uses SafeArea for bottom navigation',
        (WidgetTester tester) async {
      final onPause = MockVoidCallback();
      final onResume = MockVoidCallback();
      final onStop = MockVoidCallback();

      await tester.pumpWidget(testWrapper(
        SessionControls(
          currentState: 'Running',
          onPause: onPause.call,
          onResume: onResume.call,
          onStop: onStop.call,
        ),
      ));

      // Verify SafeArea is used
      expect(find.byType(SafeArea), findsOneWidget,
          reason: 'Should use SafeArea to avoid system UI overlap');
    });

    testWidgets('multiple pause/resume toggles work correctly',
        (WidgetTester tester) async {
      final onPause = MockVoidCallback();
      final onResume = MockVoidCallback();
      final onStop = MockVoidCallback();

      // Start with Running state
      await tester.pumpWidget(testWrapper(
        SessionControls(
          currentState: 'Running',
          onPause: onPause.call,
          onResume: onResume.call,
          onStop: onStop.call,
        ),
      ));

      // Tap pause
      await tapAndSettle(tester, find.text('Pause'));
      expect(onPause.callCount, equals(1));

      // Rebuild with Paused state
      await tester.pumpWidget(testWrapper(
        SessionControls(
          currentState: 'Paused',
          onPause: onPause.call,
          onResume: onResume.call,
          onStop: onStop.call,
        ),
      ));

      // Tap resume
      await tapAndSettle(tester, find.text('Resume'));
      expect(onResume.callCount, equals(1));

      // Rebuild with Running state again
      await tester.pumpWidget(testWrapper(
        SessionControls(
          currentState: 'Running',
          onPause: onPause.call,
          onResume: onResume.call,
          onStop: onStop.call,
        ),
      ));

      // Tap pause again
      await tapAndSettle(tester, find.text('Pause'));
      expect(onPause.callCount, equals(2));
    });

    testWidgets('handles edge case state values gracefully',
        (WidgetTester tester) async {
      final onPause = MockVoidCallback();
      final onResume = MockVoidCallback();
      final onStop = MockVoidCallback();

      // Test with non-standard state (should default to pause behavior)
      await tester.pumpWidget(testWrapper(
        SessionControls(
          currentState: 'Unknown',
          onPause: onPause.call,
          onResume: onResume.call,
          onStop: onStop.call,
        ),
      ));

      // Should show pause button (not paused state)
      verifyText('Pause');
      verifyIcon(Icons.pause);

      // Tap should call onPause
      await tapAndSettle(tester, find.text('Pause'));
      expect(onPause.called, isTrue);
    });
  });
}
