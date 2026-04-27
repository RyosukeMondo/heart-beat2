import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/screens/calendar_screen.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('CalendarScreen Widget Rendering', () {
    testWidgets('CalendarScreen can be instantiated with key', (tester) async {
      const widget = CalendarScreen(key: Key('calendar'));
      await tester.pumpWidget(testWrapper(widget));
      expect(find.byType(CalendarScreen), findsOneWidget);
    });

    testWidgets('CalendarScreen renders AppBar with title', (tester) async {
      const widget = CalendarScreen();
      await tester.pumpWidget(testWrapper(widget));
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Training Calendar'), findsOneWidget);
    });

    testWidgets('CalendarScreen can be created with default key', (tester) async {
      const widget = CalendarScreen();
      await tester.pumpWidget(testWrapper(widget));
      expect(find.byType(CalendarScreen), findsOneWidget);
    });

    testWidgets('CalendarScreen shows error state with retry when FFI fails',
        (tester) async {
      const widget = CalendarScreen();
      await tester.pumpWidget(testWrapper(widget));
      await tester.pumpAndSettle();

      // Error state shows error icon and retry button
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('CalendarScreen error message indicates failure',
        (tester) async {
      const widget = CalendarScreen();
      await tester.pumpWidget(testWrapper(widget));
      await tester.pumpAndSettle();

      // Error message should indicate load failure
      expect(find.textContaining('Failed to load'), findsOneWidget);
    });

    testWidgets('CalendarScreen shows no ListView in error state',
        (tester) async {
      const widget = CalendarScreen();
      await tester.pumpWidget(testWrapper(widget));
      await tester.pumpAndSettle();

      // Error state does not show ListView (no plan loaded)
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('CalendarScreen shows no navigation buttons in error state',
        (tester) async {
      const widget = CalendarScreen();
      await tester.pumpWidget(testWrapper(widget));
      await tester.pumpAndSettle();

      // Navigation buttons only appear when plan is loaded
      expect(find.text('Previous Week'), findsNothing);
      expect(find.text('Next Week'), findsNothing);
    });

    testWidgets('CalendarScreen shows no week sessions in error state',
        (tester) async {
      const widget = CalendarScreen();
      await tester.pumpWidget(testWrapper(widget));
      await tester.pumpAndSettle();

      // Week sessions only appear when plan is loaded
      expect(find.textContaining('Week of'), findsNothing);
      expect(find.text('Weekly Compliance'), findsNothing);
    });

    testWidgets('CalendarScreen retry button is tappable',
        (tester) async {
      const widget = CalendarScreen();
      await tester.pumpWidget(testWrapper(widget));
      await tester.pumpAndSettle();

      // Tap retry button - should not crash
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Still in error state (FFI still unavailable)
      expect(find.byType(CalendarScreen), findsOneWidget);
    });

    testWidgets('CalendarScreen error state does not show training blocks',
        (tester) async {
      const widget = CalendarScreen();
      await tester.pumpWidget(testWrapper(widget));
      await tester.pumpAndSettle();

      // Training blocks only show when plan is loaded
      expect(find.text('Training Blocks'), findsNothing);
    });

  });
}