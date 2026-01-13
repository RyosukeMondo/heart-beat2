import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/widgets/zone_indicator.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/domain/heart_rate.dart';
import 'golden_test_helpers.dart';

/// Golden tests for ZoneIndicator widget.
///
/// These tests capture screenshots of the ZoneIndicator widget for all 5
/// training zones to detect visual regressions in:
/// - Zone colors (blue, green, yellow, orange, red)
/// - Layout and spacing
/// - Text formatting and labels
/// - Border and background styling
///
/// Run with:
///   flutter test test/golden/zone_indicator_golden_test.dart
///
/// Update golden files with:
///   flutter test test/golden/zone_indicator_golden_test.dart --update-goldens
void main() {
  group('ZoneIndicator Golden Tests', () {
    testWidgets('renders Zone 1 (Recovery) correctly', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act
      await tester.pumpWidget(goldenWrapper(const ZoneIndicator(zone: Zone.zone1)));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(ZoneIndicator),
        matchesGoldenFile('goldens/zone_indicator_zone1.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders Zone 2 (Fat Burning) correctly', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act
      await tester.pumpWidget(goldenWrapper(const ZoneIndicator(zone: Zone.zone2)));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(ZoneIndicator),
        matchesGoldenFile('goldens/zone_indicator_zone2.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders Zone 3 (Aerobic) correctly', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act
      await tester.pumpWidget(goldenWrapper(const ZoneIndicator(zone: Zone.zone3)));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(ZoneIndicator),
        matchesGoldenFile('goldens/zone_indicator_zone3.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders Zone 4 (Threshold) correctly', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act
      await tester.pumpWidget(goldenWrapper(const ZoneIndicator(zone: Zone.zone4)));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(ZoneIndicator),
        matchesGoldenFile('goldens/zone_indicator_zone4.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders Zone 5 (Maximum) correctly', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act
      await tester.pumpWidget(goldenWrapper(const ZoneIndicator(zone: Zone.zone5)));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(ZoneIndicator),
        matchesGoldenFile('goldens/zone_indicator_zone5.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('Zone 1 renders in dark theme correctly', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act
      await tester.pumpWidget(goldenWrapperDark(const ZoneIndicator(zone: Zone.zone1)));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(ZoneIndicator),
        matchesGoldenFile('goldens/zone_indicator_zone1_dark.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('Zone 5 renders in dark theme correctly', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act
      await tester.pumpWidget(goldenWrapperDark(const ZoneIndicator(zone: Zone.zone5)));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(ZoneIndicator),
        matchesGoldenFile('goldens/zone_indicator_zone5_dark.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });
  });
}
