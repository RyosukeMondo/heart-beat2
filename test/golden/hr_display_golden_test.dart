import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/widgets/hr_display.dart';
import 'golden_test_helpers.dart';

/// Golden tests for HrDisplay widget.
///
/// These tests capture screenshots of the HrDisplay widget at various BPM
/// values to detect visual regressions in:
/// - Font size and weight
/// - Layout and spacing
/// - Text alignment
/// - Digit rendering (tabular figures)
///
/// Run with:
///   flutter test test/golden/hr_display_golden_test.dart
///
/// Update golden files with:
///   flutter test test/golden/hr_display_golden_test.dart --update-goldens
void main() {
  group('HrDisplay Golden Tests', () {
    testWidgets('renders 60 BPM correctly', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act
      await tester.pumpWidget(goldenWrapper(const HrDisplay(bpm: 60)));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(HrDisplay),
        matchesGoldenFile('goldens/hr_display_60bpm.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders 150 BPM correctly', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act
      await tester.pumpWidget(goldenWrapper(const HrDisplay(bpm: 150)));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(HrDisplay),
        matchesGoldenFile('goldens/hr_display_150bpm.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders 200 BPM correctly', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act
      await tester.pumpWidget(goldenWrapper(const HrDisplay(bpm: 200)));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(HrDisplay),
        matchesGoldenFile('goldens/hr_display_200bpm.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders 0 BPM correctly', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act
      await tester.pumpWidget(goldenWrapper(const HrDisplay(bpm: 0)));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(HrDisplay),
        matchesGoldenFile('goldens/hr_display_0bpm.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders single digit (5 BPM) correctly', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act
      await tester.pumpWidget(goldenWrapper(const HrDisplay(bpm: 5)));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(HrDisplay),
        matchesGoldenFile('goldens/hr_display_5bpm.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders max value (255 BPM) correctly', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act
      await tester.pumpWidget(goldenWrapper(const HrDisplay(bpm: 255)));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(HrDisplay),
        matchesGoldenFile('goldens/hr_display_255bpm.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders in dark theme correctly', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Act
      await tester.pumpWidget(goldenWrapperDark(const HrDisplay(bpm: 120)));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(HrDisplay),
        matchesGoldenFile('goldens/hr_display_120bpm_dark.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('tabular figures maintain consistent width', (tester) async {
      // Test that different digit combinations maintain the same width
      // This test compares 111 BPM visually to verify tabular figures work

      // Arrange
      setupGoldenTest(tester);

      // Act
      await tester.pumpWidget(goldenWrapper(const HrDisplay(bpm: 111)));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(HrDisplay),
        matchesGoldenFile('goldens/hr_display_111bpm_tabular.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });
  });
}
