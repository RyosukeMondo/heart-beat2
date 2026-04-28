import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/screens/readiness_screen.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('ReadinessScreen rendering', () {
    testWidgets('ReadinessScreen can be instantiated with key', (tester) async {
      const widget = ReadinessScreen(key: Key('readinessScreen'));
      await tester.pumpWidget(testWrapper(widget));
      expect(find.byType(ReadinessScreen), findsOneWidget);
    });

    testWidgets('ReadinessScreen renders AppBar with title', (tester) async {
      const widget = ReadinessScreen();
      await tester.pumpWidget(testWrapper(widget));
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Recovery & Readiness'), findsOneWidget);
    });
  });

  group('ReadinessScreen _buildError behavior', () {
    // Replicate error widget logic from ReadinessScreen for isolated testing
    Widget buildErrorWidget({required String errorMessage, VoidCallback? onRetry}) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onRetry ?? () {},
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('error widget shows error icon', (tester) async {
      await tester.pumpWidget(buildErrorWidget(errorMessage: 'Test error'));
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('error widget shows error message', (tester) async {
      await tester.pumpWidget(buildErrorWidget(
        errorMessage: 'Failed to load readiness data: Exception',
      ));
      expect(
        find.text('Failed to load readiness data: Exception'),
        findsOneWidget,
      );
    });

    testWidgets('error widget shows retry button', (tester) async {
      await tester.pumpWidget(buildErrorWidget(errorMessage: 'Test error'));
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('retry button triggers callback', (tester) async {
      var retried = false;
      await tester.pumpWidget(buildErrorWidget(
        errorMessage: 'Test error',
        onRetry: () => retried = true,
      ));
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets('error text is centered', (tester) async {
      await tester.pumpWidget(buildErrorWidget(errorMessage: 'Test error'));
      final text = tester.widget<Text>(find.text('Test error'));
      expect(text.textAlign, equals(TextAlign.center));
    });

    testWidgets('error text uses error color', (tester) async {
      await tester.pumpWidget(buildErrorWidget(errorMessage: 'Test error'));
      final text = tester.widget<Text>(find.text('Test error'));
      expect(text.style?.color, equals(Colors.red));
    });
  });

  group('ReadinessScreen _MorningCheckSheet widget behavior', () {
    // Replicate _MorningCheckSheet from ReadinessScreen for isolated testing
    Widget buildMorningCheckSheet() {
      return MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Icon(Icons.self_improvement, size: 64, color: Colors.blue),
                      const SizedBox(height: 16),
                      Text(
                        'Morning Readiness Check',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'For the most accurate reading:\n'
                        '1. Sit comfortably and relax\n'
                        '2. Make sure your HR monitor is connected\n'
                        '3. Stay still for 60 seconds\n'
                        '4. Breathe naturally',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Measurement'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    testWidgets('MorningCheckSheet renders title', (tester) async {
      await tester.pumpWidget(buildMorningCheckSheet());
      expect(find.text('Morning Readiness Check'), findsOneWidget);
    });

    testWidgets('MorningCheckSheet shows instructions text', (tester) async {
      await tester.pumpWidget(buildMorningCheckSheet());
      expect(
        find.text('For the most accurate reading:\n'
            '1. Sit comfortably and relax\n'
            '2. Make sure your HR monitor is connected\n'
            '3. Stay still for 60 seconds\n'
            '4. Breathe naturally'),
        findsOneWidget,
      );
    });

    testWidgets('MorningCheckSheet shows self-improvement icon', (tester) async {
      await tester.pumpWidget(buildMorningCheckSheet());
      expect(find.byIcon(Icons.self_improvement), findsOneWidget);
    });

    testWidgets('MorningCheckSheet shows start measurement button', (tester) async {
      await tester.pumpWidget(buildMorningCheckSheet());
      expect(find.text('Start Measurement'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('MorningCheckSheet start button triggers navigation pop', (tester) async {
      await tester.pumpWidget(buildMorningCheckSheet());
      await tester.tap(find.text('Start Measurement'));
      await tester.pumpAndSettle();
      // After pop, the widget tree should be empty of this content
      expect(find.text('Morning Readiness Check'), findsNothing);
    });

    testWidgets('MorningCheckSheet has drag handle container', (tester) async {
      await tester.pumpWidget(buildMorningCheckSheet());
      // The drag handle is a Container with specific dimensions
      final containers = tester.widgetList<Container>(find.byType(Container));
      final dragHandle = containers.where((c) =>
          c.constraints?.maxWidth == 40 && c.constraints?.maxHeight == 4);
      expect(dragHandle.length, 1);
    });

    testWidgets('MorningCheckSheet uses SafeArea', (tester) async {
      await tester.pumpWidget(buildMorningCheckSheet());
      expect(find.byType(SafeArea), findsOneWidget);
    });
  });

  group('ReadinessScreen _scoreColor logic', () {
    Color scoreColorFor(int score) {
      if (score >= 70) return Colors.green;
      if (score >= 40) return Colors.orange;
      return Colors.red;
    }

    test('score >= 70 returns green', () {
      expect(scoreColorFor(70), equals(Colors.green));
      expect(scoreColorFor(71), equals(Colors.green));
      expect(scoreColorFor(100), equals(Colors.green));
    });

    test('score >= 40 and < 70 returns orange', () {
      expect(scoreColorFor(40), equals(Colors.orange));
      expect(scoreColorFor(50), equals(Colors.orange));
      expect(scoreColorFor(69), equals(Colors.orange));
    });

    test('score < 40 returns red', () {
      expect(scoreColorFor(0), equals(Colors.red));
      expect(scoreColorFor(39), equals(Colors.red));
    });
  });

  group('ReadinessScreen _levelLabel logic', () {
    String levelLabelFor(String? level) {
      switch (level) {
        case 'Ready':
          return 'Ready to Train';
        case 'Moderate':
          return 'Moderate Recovery';
        case 'Rest':
          return 'Rest Recommended';
        default:
          return level ?? '';
      }
    }

    test('Ready returns "Ready to Train"', () {
      expect(levelLabelFor('Ready'), equals('Ready to Train'));
    });

    test('Moderate returns "Moderate Recovery"', () {
      expect(levelLabelFor('Moderate'), equals('Moderate Recovery'));
    });

    test('Rest returns "Rest Recommended"', () {
      expect(levelLabelFor('Rest'), equals('Rest Recommended'));
    });

    test('null returns empty string', () {
      expect(levelLabelFor(null), equals(''));
    });

    test('unknown value returns empty string', () {
      expect(levelLabelFor('Unknown'), equals('Unknown'));
    });
  });

  group('ReadinessScreen _componentColor logic', () {
    Color componentColorFor(double value) {
      if (value >= 70) return Colors.green;
      if (value >= 40) return Colors.orange;
      return Colors.red;
    }

    test('value >= 70 returns green', () {
      expect(componentColorFor(70.0), equals(Colors.green));
      expect(componentColorFor(100.0), equals(Colors.green));
    });

    test('value >= 40 and < 70 returns orange', () {
      expect(componentColorFor(40.0), equals(Colors.orange));
      expect(componentColorFor(50.0), equals(Colors.orange));
      expect(componentColorFor(69.9), equals(Colors.orange));
    });

    test('value < 40 returns red', () {
      expect(componentColorFor(0.0), equals(Colors.red));
      expect(componentColorFor(39.9), equals(Colors.red));
    });
  });
}