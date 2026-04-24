import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/screens/session_screen.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('SessionScreen Widget Rendering', () {
    testWidgets('SessionScreen can be instantiated with key', (tester) async {
      const widget = SessionScreen(key: Key('sessionScreen'));
      await tester.pumpWidget(testWrapper(widget));
      expect(find.byType(SessionScreen), findsOneWidget);
    });

    testWidgets('SessionScreen renders AppBar with title', (tester) async {
      const widget = SessionScreen();
      await tester.pumpWidget(testWrapper(widget));
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('SessionScreen can be created with default key', (tester) async {
      const widget = SessionScreen();
      await tester.pumpWidget(testWrapper(widget));
      expect(find.byType(SessionScreen), findsOneWidget);
    });

    testWidgets('SessionScreen shows connecting state initially',
        (tester) async {
      const widget = SessionScreen();
      await tester.pumpWidget(testWrapper(widget));

      // Initial state should show connecting indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Connecting to device...'), findsOneWidget);
    });
  });
}