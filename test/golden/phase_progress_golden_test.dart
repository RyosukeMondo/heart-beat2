import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/widgets/phase_progress.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/domain/heart_rate.dart';
import 'golden_test_helpers.dart';

/// Golden tests for PhaseProgressWidget.
///
/// These tests capture screenshots of the PhaseProgressWidget for different
/// workout phases to detect visual regressions in:
/// - Phase name display
/// - Progress bar rendering with zone colors
/// - Time formatting and layout
/// - Different progress states (start, middle, end)
///
/// Run with:
///   flutter test test/golden/phase_progress_golden_test.dart
///
/// Update golden files with:
///   flutter test test/golden/phase_progress_golden_test.dart --update-goldens
void main() {
  group('PhaseProgressWidget Golden Tests', () {
    testWidgets('renders Warmup phase at start', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act - Warmup phase just started (10s elapsed, 290s remaining)
      await tester.pumpWidget(goldenWrapper(
        const PhaseProgressWidget(
          phaseName: 'Warmup',
          targetZone: Zone.zone1,
          elapsedSecs: 10,
          remainingSecs: 290,
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(PhaseProgressWidget),
        matchesGoldenFile('goldens/phase_progress_warmup.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders Active phase at middle', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act - Active phase halfway (600s elapsed, 600s remaining)
      await tester.pumpWidget(goldenWrapper(
        const PhaseProgressWidget(
          phaseName: 'Work',
          targetZone: Zone.zone4,
          elapsedSecs: 600,
          remainingSecs: 600,
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(PhaseProgressWidget),
        matchesGoldenFile('goldens/phase_progress_active.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders Cooldown phase near end', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act - Cooldown phase almost done (270s elapsed, 30s remaining)
      await tester.pumpWidget(goldenWrapper(
        const PhaseProgressWidget(
          phaseName: 'Cooldown',
          targetZone: Zone.zone1,
          elapsedSecs: 270,
          remainingSecs: 30,
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(PhaseProgressWidget),
        matchesGoldenFile('goldens/phase_progress_cooldown.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders Recovery phase with zone 2', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act - Recovery phase (180s elapsed, 120s remaining)
      await tester.pumpWidget(goldenWrapper(
        const PhaseProgressWidget(
          phaseName: 'Recovery',
          targetZone: Zone.zone2,
          elapsedSecs: 180,
          remainingSecs: 120,
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(PhaseProgressWidget),
        matchesGoldenFile('goldens/phase_progress_recovery.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders Interval phase with zone 5', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act - High intensity interval (60s elapsed, 60s remaining)
      await tester.pumpWidget(goldenWrapper(
        const PhaseProgressWidget(
          phaseName: 'Interval',
          targetZone: Zone.zone5,
          elapsedSecs: 60,
          remainingSecs: 60,
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(PhaseProgressWidget),
        matchesGoldenFile('goldens/phase_progress_interval.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders phase at 0% progress', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act - Phase just started (0s elapsed, 300s remaining)
      await tester.pumpWidget(goldenWrapper(
        const PhaseProgressWidget(
          phaseName: 'Warmup',
          targetZone: Zone.zone1,
          elapsedSecs: 0,
          remainingSecs: 300,
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(PhaseProgressWidget),
        matchesGoldenFile('goldens/phase_progress_0percent.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders phase at 100% progress', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act - Phase complete (300s elapsed, 0s remaining)
      await tester.pumpWidget(goldenWrapper(
        const PhaseProgressWidget(
          phaseName: 'Work',
          targetZone: Zone.zone3,
          elapsedSecs: 300,
          remainingSecs: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(PhaseProgressWidget),
        matchesGoldenFile('goldens/phase_progress_100percent.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders in dark theme', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act
      await tester.pumpWidget(goldenWrapperDark(
        const PhaseProgressWidget(
          phaseName: 'Work',
          targetZone: Zone.zone4,
          elapsedSecs: 360,
          remainingSecs: 240,
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(PhaseProgressWidget),
        matchesGoldenFile('goldens/phase_progress_dark.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders time formatting correctly', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act - Test time formatting with specific values (12:34 elapsed, 56:07 remaining)
      await tester.pumpWidget(goldenWrapper(
        const PhaseProgressWidget(
          phaseName: 'Endurance',
          targetZone: Zone.zone2,
          elapsedSecs: 754, // 12:34
          remainingSecs: 3367, // 56:07
        ),
      ));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(PhaseProgressWidget),
        matchesGoldenFile('goldens/phase_progress_time_format.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });
  });
}
