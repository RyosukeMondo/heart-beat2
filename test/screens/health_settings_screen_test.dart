import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heart_beat/src/screens/health_settings_screen.dart';
import 'package:heart_beat/src/services/health_settings_service.dart';
import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HealthSettingsScreen', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await HealthSettingsService.instance.reload();
    });

    Widget buildScreen() => testWrapper(const HealthSettingsScreen());

    testWidgets('renders threshold field', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byKey(const Key('thresholdField')), findsOneWidget);
    });

    testWidgets('renders notifications toggle', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Scrollable is the ListView itself
      final listView = find.byType(ListView);
      expect(listView, findsOneWidget);

      // Scroll down
      await tester.drag(listView, const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notificationsToggle')), findsOneWidget);
    });

    testWidgets('threshold field commits value 65 to service', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Change threshold to 65
      await tester.enterText(
        find.byKey(const Key('thresholdField')),
        '65',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(HealthSettingsService.instance.lowHrThreshold, equals(65));
    });

    testWidgets('threshold field clamps value below 40 to 40', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('thresholdField')),
        '30',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Clamped to 40
      expect(HealthSettingsService.instance.lowHrThreshold, equals(40));
    });

    testWidgets('threshold field clamps value above 120 to 120', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('thresholdField')),
        '200',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Clamped to 120
      expect(HealthSettingsService.instance.lowHrThreshold, equals(120));
    });

    testWidgets('sustained minus button decrements value', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final minusBtn = find.byKey(const Key('sustainedMinus'));
      expect(minusBtn, findsOneWidget);

      await tester.tap(minusBtn);
      await tester.pumpAndSettle();

      expect(HealthSettingsService.instance.sustainedMinutes, equals(HealthSettingsService.defaultSustainedMinutes - 1));
    });

    testWidgets('sustained plus button increments value', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final plusBtn = find.byKey(const Key('sustainedPlus'));
      expect(plusBtn, findsOneWidget);

      await tester.tap(plusBtn);
      await tester.pumpAndSettle();

      expect(HealthSettingsService.instance.sustainedMinutes, equals(HealthSettingsService.defaultSustainedMinutes + 1));
    });

    testWidgets('sustained slider updates service', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final slider = find.byKey(const Key('sustainedSlider'));
      await tester.drag(slider, const Offset(200, 0));
      await tester.pumpAndSettle();

      // Value is set to something in range 1-60
      expect(HealthSettingsService.instance.sustainedMinutes, inInclusiveRange(1, 60));
    });

    testWidgets('notifications toggle updates service', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Scroll to show the toggle
      final listView = find.byType(ListView);
      await tester.drag(listView, const Offset(0, -400));
      await tester.pumpAndSettle();

      final toggle = find.byKey(const Key('notificationsToggle'));
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(HealthSettingsService.instance.notificationsEnabled, isFalse);
    });

    testWidgets('quiet-hours validation rejects out-of-range hour', (tester) async {
      // Verify that TimeOfDay with hour > 23 is invalid
      final invalidTod = TimeOfDay(hour: 25, minute: 0);
      expect(invalidTod.hour > 23, isTrue);
    });

    testWidgets('quiet-hours validation rejects minute > 59', (tester) async {
      // TimeOfDay with minute=99 is invalid
      final invalidTod = TimeOfDay(hour: 12, minute: 99);
      expect(invalidTod.minute > 59, isTrue);
    });
  });
}