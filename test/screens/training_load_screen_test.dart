import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/screens/training_load_screen.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('TrainingLoadScreen Widget Rendering', () {
    testWidgets('TrainingLoadScreen can be instantiated with key', (tester) async {
      const widget = TrainingLoadScreen(key: Key('training_load'));
      await tester.pumpWidget(testWrapper(widget));
      expect(find.byType(TrainingLoadScreen), findsOneWidget);
    });

    testWidgets('TrainingLoadScreen renders AppBar with title', (tester) async {
      const widget = TrainingLoadScreen();
      await tester.pumpWidget(testWrapper(widget));
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Training Load'), findsOneWidget);
    });

    testWidgets('TrainingLoadScreen can be created with default key', (tester) async {
      const widget = TrainingLoadScreen();
      await tester.pumpWidget(testWrapper(widget));
      expect(find.byType(TrainingLoadScreen), findsOneWidget);
    });

    testWidgets('TrainingLoadScreen renders scaffold body', (tester) async {
      const widget = TrainingLoadScreen();
      await tester.pumpWidget(testWrapper(widget));
      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
    });
  });
}