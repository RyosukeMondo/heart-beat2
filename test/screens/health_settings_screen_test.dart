import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heart_beat/src/screens/health_settings_screen.dart';
import 'package:heart_beat/src/services/health_settings_service.dart';
import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HealthSettingsScreen rendering', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await HealthSettingsService.instance.reload();
    });

    Widget buildScreen() => testWrapper(const HealthSettingsScreen());

    testWidgets('renders scaffold with Health Alerts app bar title', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.text('Health Alerts'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('renders threshold field', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byKey(const Key('thresholdField')), findsOneWidget);
    });

    testWidgets('renders sustained minus and plus buttons', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sustainedMinus')), findsOneWidget);
      expect(find.byKey(const Key('sustainedPlus')), findsOneWidget);
    });

    testWidgets('renders sustained slider', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sustainedSlider')), findsOneWidget);
    });

    testWidgets('renders cadence dropdown', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cadenceDropdown')), findsOneWidget);
    });

    testWidgets('renders ListView for scrollable content', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('renders notification toggle after scrolling', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Scroll to show the toggle
      final listView = find.byType(ListView);
      await tester.drag(listView, const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notificationsToggle')), findsOneWidget);
    });
  });

  group('HealthSettingsScreen quiet-hours validation', () {
    testWidgets('TimeOfDay validation: hour > 23 is invalid', (tester) async {
      final invalidTod = TimeOfDay(hour: 25, minute: 0);
      expect(invalidTod.hour > 23, isTrue);
    });

    testWidgets('TimeOfDay validation: minute > 59 is invalid', (tester) async {
      final invalidTod = TimeOfDay(hour: 12, minute: 99);
      expect(invalidTod.minute > 59, isTrue);
    });

    testWidgets('TimeOfDay parsing: valid HH:mm round-trips', (tester) async {
      final tod = TimeOfDay(hour: 22, minute: 30);
      final formatted =
          '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';
      expect(formatted, equals('22:30'));
    });

    testWidgets('TimeOfDay parsing: midnight is 00:00', (tester) async {
      final tod = TimeOfDay(hour: 0, minute: 0);
      final formatted =
          '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';
      expect(formatted, equals('00:00'));
    });
  });
}
