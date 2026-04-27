import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/domain/heart_rate.dart';
import 'package:heart_beat/src/services/coaching_helpers.dart';
import 'package:heart_beat/src/widgets/hr_display.dart';
import 'package:heart_beat/src/widgets/zone_indicator.dart';
import '../helpers/test_helpers.dart';

/// Unit and widget tests for coaching screen components.
///
/// This file tests the constituent widgets and helper logic that make up
/// the coaching session screen. Full integration testing of the coaching
/// screen requires Rust FFI initialization (RustLib.init) and is covered
/// by integration tests instead.
///
/// Tests cover:
/// - HR display component in coaching context
/// - Zone indicator component in coaching context
/// - Session timer and zone tracking logic
/// - Coaching cue card rendering
///
/// The coaching screen itself (_CoachingScreenState) creates FFI streams
/// directly in initState via api.createHrStream(), api.createConnectionStatusStream(),
/// and api.createCoachingCueStream(), which requires RustLib.init() before
/// the widget can be instantiated in tests.
void main() {
  group('Coaching HR Display Tests', () {
    testWidgets('renders HR display with large BPM in coaching context',
        (tester) async {
      // Arrange - HR display is the main coaching component
      const widget = HrDisplay(bpm: 145);

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      expect(find.text('145'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
    });

    testWidgets('HR display uses bold font for BPM value', (tester) async {
      // Arrange - typical coaching session HR
      const widget = HrDisplay(bpm: 155);

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      final bpmText = tester.widget<Text>(find.text('155'));
      expect(bpmText.style?.fontWeight, equals(FontWeight.bold));
      expect(bpmText.style?.fontSize, equals(72));
    });

    testWidgets('HR display shows tabular figures for consistent width',
        (tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 120);

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      final bpmText = tester.widget<Text>(find.text('120'));
      expect(
        bpmText.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    testWidgets('renders various coaching-relevant BPM values', (tester) async {
      // Zone 2 range (60-70% max HR assuming 180 max)
      await tester.pumpWidget(testWrapper(const HrDisplay(bpm: 108)));
      expect(find.text('108'), findsOneWidget);

      // Zone 3 range (70-80%)
      await tester.pumpWidget(testWrapper(const HrDisplay(bpm: 135)));
      expect(find.text('135'), findsOneWidget);

      // Zone 4 range (80-90%)
      await tester.pumpWidget(testWrapper(const HrDisplay(bpm: 162)));
      expect(find.text('162'), findsOneWidget);

      // Zone 5 range (90-100%)
      await tester.pumpWidget(testWrapper(const HrDisplay(bpm: 175)));
      expect(find.text('175'), findsOneWidget);
    });
  });

  group('Coaching Zone Indicator Tests', () {
    testWidgets('renders zone indicator for each zone', (tester) async {
      for (final zone in Zone.values) {
        await tester.pumpWidget(testWrapper(ZoneIndicator(zone: zone)));
        expect(find.byType(ZoneIndicator), findsOneWidget);
      }
    });

    testWidgets('zone indicator shows correct zone name', (tester) async {
      await tester.pumpWidget(testWrapper(const ZoneIndicator(zone: Zone.zone3)));
      expect(find.text('Zone 3 (Aerobic)'), findsOneWidget);
    });

    testWidgets('zone indicator shows zone text for all zones', (tester) async {
      // Zone 1
      await tester.pumpWidget(testWrapper(const ZoneIndicator(zone: Zone.zone1)));
      expect(find.text('Zone 1 (Recovery)'), findsOneWidget);

      // Zone 2
      await tester.pumpWidget(testWrapper(const ZoneIndicator(zone: Zone.zone2)));
      expect(find.text('Zone 2 (Fat Burning)'), findsOneWidget);

      // Zone 3
      await tester.pumpWidget(testWrapper(const ZoneIndicator(zone: Zone.zone3)));
      expect(find.text('Zone 3 (Aerobic)'), findsOneWidget);

      // Zone 4
      await tester.pumpWidget(testWrapper(const ZoneIndicator(zone: Zone.zone4)));
      expect(find.text('Zone 4 (Threshold)'), findsOneWidget);

      // Zone 5
      await tester.pumpWidget(testWrapper(const ZoneIndicator(zone: Zone.zone5)));
      expect(find.text('Zone 5 (Maximum)'), findsOneWidget);
    });
  });

  group('Coaching Session Timer Logic Tests', () {
    test('duration formatting shows hours when > 60 minutes', () {
      const duration = Duration(hours: 1, minutes: 30, seconds: 45);
      final formatted = CoachingHelpers.formatDuration(duration);
      expect(formatted, equals('1h 30m 45s'));
    });

    test('duration formatting shows minutes and seconds without hours', () {
      const duration = Duration(minutes: 5, seconds: 30);
      final formatted = CoachingHelpers.formatDuration(duration);
      expect(formatted, equals('5m 30s'));
    });

    test('duration formatting handles zero duration', () {
      const duration = Duration.zero;
      final formatted = CoachingHelpers.formatDuration(duration);
      expect(formatted, equals('0m 0s'));
    });

    test('duration formatting handles exactly one hour', () {
      const duration = Duration(hours: 1);
      final formatted = CoachingHelpers.formatDuration(duration);
      expect(formatted, equals('1h 0m 0s'));
    });

    test('duration formatting handles long sessions', () {
      const duration = Duration(hours: 8, minutes: 45, seconds: 12);
      final formatted = CoachingHelpers.formatDuration(duration);
      expect(formatted, equals('8h 45m 12s'));
    });
  });

  group('Coaching Cue Card Tests', () {
    testWidgets('cue card priority colors are correct', (tester) async {
      expect(CoachingHelpers.cuePriorityColor(0), equals(Colors.grey));
      expect(CoachingHelpers.cuePriorityColor(1), equals(Colors.blue));
      expect(CoachingHelpers.cuePriorityColor(2), equals(Colors.orange));
      expect(CoachingHelpers.cuePriorityColor(3), equals(Colors.red));
      expect(CoachingHelpers.cuePriorityColor(99), equals(Colors.grey));
    });

    testWidgets('cue priority labels are correct', (tester) async {
      expect(CoachingHelpers.priorityLabel(0), equals('LOW'));
      expect(CoachingHelpers.priorityLabel(1), equals('NORMAL'));
      expect(CoachingHelpers.priorityLabel(2), equals('HIGH'));
      expect(CoachingHelpers.priorityLabel(3), equals('CRITICAL'));
      expect(CoachingHelpers.priorityLabel(99), equals('UNKNOWN'));
    });

    testWidgets('cue source icons are assigned correctly', (tester) async {
      expect(CoachingHelpers.cueSourceIcon(0), equals(Icons.track_changes));
      expect(CoachingHelpers.cueSourceIcon(1), equals(Icons.airline_seat_flat));
      expect(CoachingHelpers.cueSourceIcon(2), equals(Icons.whatshot));
      expect(CoachingHelpers.cueSourceIcon(99), equals(Icons.info));
    });

    testWidgets('cue label text formatting works', (tester) async {
      expect(CoachingHelpers.cueLabelText('raise_hr'), equals('Raise HR'));
      expect(CoachingHelpers.cueLabelText('cool_down'), equals('Cool Down'));
      expect(CoachingHelpers.cueLabelText('stand_up'), equals('Stand Up'));
      expect(CoachingHelpers.cueLabelText('ease_off'), equals('Ease Off'));
      expect(CoachingHelpers.cueLabelText('unknown_label'), equals('Unknown Label'));
    });
  });

  group('Coaching Zone Color Tests', () {
    testWidgets('zone colors match coaching UI expectations', (tester) async {
      // Zone 1 - recovery/easy
      expect(CoachingHelpers.zoneColor(Zone.zone1), equals(Colors.blue));

      // Zone 2 - aerobic
      expect(CoachingHelpers.zoneColor(Zone.zone2), equals(Colors.green));

      // Zone 3 - tempo
      expect(CoachingHelpers.zoneColor(Zone.zone3), equals(Colors.yellow.shade700));

      // Zone 4 - threshold
      expect(CoachingHelpers.zoneColor(Zone.zone4), equals(Colors.orange));

      // Zone 5 - VO2max/anaerobic
      expect(CoachingHelpers.zoneColor(Zone.zone5), equals(Colors.red));
    });

    testWidgets('zone icons match coaching UI expectations', (tester) async {
      // Each zone has a distinct coaching-relevant icon
      expect(CoachingHelpers.zoneIcon(Zone.zone1), equals(Icons.airline_seat_recline_extra));
      expect(CoachingHelpers.zoneIcon(Zone.zone2), equals(Icons.directions_walk));
      expect(CoachingHelpers.zoneIcon(Zone.zone3), equals(Icons.directions_run));
      expect(CoachingHelpers.zoneIcon(Zone.zone4), equals(Icons.sports_gymnastics));
      expect(CoachingHelpers.zoneIcon(Zone.zone5), equals(Icons.local_fire_department));
    });
  });

  group('Coaching Screen Helper Integration', () {
    test('helper methods return expected CoachingHelpers values', () {
      expect(CoachingHelpers.formatDuration(const Duration(hours: 2, minutes: 15)), equals('2h 15m 0s'));
      expect(CoachingHelpers.formatDuration(const Duration(minutes: 45, seconds: 30)), equals('45m 30s'));

      expect(CoachingHelpers.zoneColor(Zone.zone3), equals(Colors.yellow.shade700));
      expect(CoachingHelpers.zoneColor(Zone.zone5), equals(Colors.red));
    });
  });
}