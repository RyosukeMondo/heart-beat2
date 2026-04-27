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

    testWidgets('SessionScreen disconnect button not visible when stream is null',
        (tester) async {
      // When _hrStream is null (not connected), the disconnect button
      // (bluetooth_disabled icon) should not be visible in AppBar
      const widget = SessionScreen();
      await tester.pumpWidget(testWrapper(widget));

      expect(find.byIcon(Icons.bluetooth_disabled), findsNothing);
    });

    testWidgets('SessionScreen shows error state when connection fails',
        (tester) async {
      // TODO: Requires API mocking to trigger _errorMessage state
      // The error state shows Icons.error_outline when _errorMessage is set
      // Skipping until API mocking is available
    }, skip: true);

    testWidgets('SessionScreen shows HR display when stream has data',
        (tester) async {
      // TODO: Requires API mocking to provide _hrStream data
      // The HR display state shows HrDisplay, ZoneIndicator widgets
      // Skipping until API mocking is available
    }, skip: true);

    testWidgets('SessionScreen shows session timer during active session',
        (tester) async {
      // TODO: Session timer not yet implemented in SessionScreen
      // When implemented, should display elapsed session time
    }, skip: true);
  });
}