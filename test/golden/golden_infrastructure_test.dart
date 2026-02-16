import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'golden_test_helpers.dart';

/// Infrastructure validation tests for golden test setup.
///
/// These tests verify that the golden test infrastructure is correctly
/// configured and produces reproducible results.
void main() {
  group('Golden Test Infrastructure', () {
    testWidgets('goldenWrapper provides Material context', (tester) async {
      // Arrange
      const testWidget = Text('Test');

      // Act
      await tester.pumpWidget(goldenWrapper(testWidget));

      // Assert - should not throw and should find the widget
      expect(find.text('Test'), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Material), findsOneWidget);
    });

    testWidgets('goldenWrapper has fixed size', (tester) async {
      // Arrange
      const testWidget = Text('Test');

      // Act
      await tester.pumpWidget(goldenWrapper(testWidget));

      // Assert
      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(MaterialApp),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(sizedBox.width, equals(800));
      expect(sizedBox.height, equals(600));
    });

    testWidgets('goldenWrapperWithSize uses custom dimensions', (tester) async {
      // Arrange
      const testWidget = Text('Test');

      // Act
      await tester.pumpWidget(goldenWrapperWithSize(
        child: testWidget,
        width: 400,
        height: 300,
      ));

      // Assert
      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(MaterialApp),
          matching: find.byType(SizedBox),
        ).first,
      );
      expect(sizedBox.width, equals(400));
      expect(sizedBox.height, equals(300));
    });

    testWidgets('goldenWrapperDark uses dark theme', (tester) async {
      // Arrange
      const testWidget = Text('Test');

      // Act
      await tester.pumpWidget(goldenWrapperDark(testWidget));

      // Assert
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme?.brightness, equals(Brightness.dark));
    });

    testWidgets('setupGoldenTest configures device settings', (tester) async {
      // Arrange & Act
      setupGoldenTest(tester);

      // Assert
      expect(tester.view.physicalSize, equals(const Size(800, 600)));
      expect(tester.view.devicePixelRatio, equals(1.0));

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('setupGoldenTest accepts custom view size', (tester) async {
      // Arrange & Act
      setupGoldenTest(tester, viewSize: const Size(1024, 768));

      // Assert
      expect(tester.view.physicalSize, equals(const Size(1024, 768)));
      expect(tester.view.devicePixelRatio, equals(1.0));

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('tearDownGoldenTest resets device settings', (tester) async {
      // Arrange
      setupGoldenTest(tester);
      expect(tester.view.devicePixelRatio, equals(1.0));

      // Act
      tearDownGoldenTest(tester);

      // Assert - should be reset to default (not 1.0)
      // Note: The actual default value depends on the test environment
      // We just verify that reset was called
      expect(tester.view.physicalSize, isNot(equals(const Size(800, 600))));
    });

    testWidgets('defaultDarkTheme matches app.dart configuration', (tester) async {
      // Arrange
      final theme = defaultDarkTheme();

      // Assert
      expect(theme.colorScheme.brightness, equals(Brightness.dark));
      expect(theme.useMaterial3, isTrue);
      // Verify it's based on red seed color by checking primary color has red hue
      final primary = theme.colorScheme.primary;
      expect((primary.r * 255.0).round(), greaterThan((primary.b * 255.0).round()));
      expect((primary.r * 255.0).round(), greaterThan((primary.g * 255.0).round()));
    });

    testWidgets('goldenWrapper applies custom theme when provided', (tester) async {
      // Arrange
      const testWidget = Text('Test');
      final customTheme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      );

      // Act
      await tester.pumpWidget(goldenWrapper(testWidget, theme: customTheme));

      // Assert
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.theme, equals(customTheme));
    });
  });
}
