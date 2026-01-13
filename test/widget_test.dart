// Widget test infrastructure setup and smoke tests.
//
// This file demonstrates the test infrastructure for widget testing.
// Individual widget tests are in test/widgets/*.
//
// The test infrastructure provides:
// - Test wrapper widgets (MaterialApp context)
// - Mock API for Rust FFI (no device required)
// - Helper utilities for common test patterns

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/domain/heart_rate.dart';

import 'helpers/test_helpers.dart';
import 'helpers/mock_api.dart';

void main() {
  group('Widget Test Infrastructure', () {
    testWidgets('testWrapper provides MaterialApp context',
        (WidgetTester tester) async {
      // Verify that testWrapper provides necessary context
      await tester.pumpWidget(
        testWrapper(
          const Text('Test Widget'),
        ),
      );

      expect(find.text('Test Widget'), findsOneWidget);
    });

    testWidgets('testWrapperWithTheme applies custom theme',
        (WidgetTester tester) async {
      final darkTheme = ThemeData.dark();

      await tester.pumpWidget(
        testWrapperWithTheme(
          theme: darkTheme,
          child: Builder(
            builder: (context) {
              // Verify dark theme is applied
              final theme = Theme.of(context);
              return Text(
                'Dark Mode',
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              );
            },
          ),
        ),
      );

      expect(find.text('Dark Mode'), findsOneWidget);
    });

    testWidgets('MockCallback tracks invocations',
        (WidgetTester tester) async {
      final callback = MockCallback<String>();

      await tester.pumpWidget(
        testWrapper(
          ElevatedButton(
            onPressed: () => callback('test-value'),
            child: const Text('Tap Me'),
          ),
        ),
      );

      expect(callback.called, isFalse);
      expect(callback.callCount, equals(0));

      await tester.tap(find.text('Tap Me'));
      await tester.pump();

      expect(callback.called, isTrue);
      expect(callback.callCount, equals(1));
      expect(callback.lastArg, equals('test-value'));
    });

    testWidgets('MockVoidCallback tracks invocations',
        (WidgetTester tester) async {
      final callback = MockVoidCallback();

      await tester.pumpWidget(
        testWrapper(
          ElevatedButton(
            onPressed: callback.call,
            child: const Text('Tap Me'),
          ),
        ),
      );

      expect(callback.called, isFalse);

      await tester.tap(find.text('Tap Me'));
      await tester.pump();

      expect(callback.called, isTrue);
      expect(callback.callCount, equals(1));
    });
  });

  group('Mock API Data Structures', () {
    test('MockPlans creates plan lists', () {
      final plans = MockPlans.defaultPlans;
      expect(plans.plans.length, equals(3));
      expect(plans.error, isNull);

      final empty = MockPlans.empty();
      expect(empty.plans, isEmpty);

      final failure = MockPlans.failure('Network error');
      expect(failure.error, equals('Network error'));
    });

    test('MockDevices creates device lists', () {
      final devices = MockDevices.defaultDevices;
      expect(devices.length, equals(3));
      expect(devices[0].name, equals('Polar H10'));

      final empty = MockDevices.empty;
      expect(empty, isEmpty);
    });

    test('MockZone provides zone data', () {
      expect(MockZone.zones.length, equals(5));
      expect(MockZone.zoneName(Zone.zone3), equals('Zone 3'));
      expect(MockZone.zoneColors.length, equals(5));
    });

    test('MockBattery creates battery levels', () {
      final full = MockBattery.full;
      expect(full.level, equals(100));
      expect(full.isCharging, isFalse);

      final charging = MockBattery.charging;
      expect(charging.isCharging, isTrue);
    });
  });
}
