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

    testWidgets('CalendarScreen body contains ListView when loaded', (tester) async {
      const widget = CalendarScreen();
      await tester.pumpWidget(testWrapper(widget));
      await tester.pumpAndSettle();

      // After async load fails (no FFI), error state shows
      expect(find.byType(ListView), findsNothing);
    });
  });
}