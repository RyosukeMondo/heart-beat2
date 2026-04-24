import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/screens/home_screen.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('HomeScreen Widget Rendering', () {
    testWidgets('HomeScreen can be instantiated with key', (tester) async {
      const widget = HomeScreen(key: Key('homeScreen'));
      await tester.pumpWidget(testWrapper(widget));
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('HomeScreen renders AppBar with title', (tester) async {
      const widget = HomeScreen();
      await tester.pumpWidget(testWrapper(widget));
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Heart Beat'), findsOneWidget);
    });

    testWidgets('HomeScreen can be created with default key', (tester) async {
      const widget = HomeScreen();
      await tester.pumpWidget(testWrapper(widget));
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('HomeScreen body contains scan button', (tester) async {
      const widget = HomeScreen();
      await tester.pumpWidget(testWrapper(widget));
      await tester.pumpAndSettle();

      // The scan button uses ElevatedButton.icon - find by text
      expect(find.text('Scan for Devices'), findsOneWidget);
    });

    testWidgets('HomeScreen renders quick action chips', (tester) async {
      const widget = HomeScreen();
      await tester.pumpWidget(testWrapper(widget));
      await tester.pumpAndSettle();

      expect(find.text('Workout Library'), findsOneWidget);
      expect(find.text('Training Load'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('Readiness'), findsOneWidget);
    });
  });
}