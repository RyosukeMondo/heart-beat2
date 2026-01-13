import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/widgets/hr_display.dart';
import '../helpers/test_helpers.dart';

/// Widget tests for HrDisplay component.
///
/// Tests BPM rendering at various values including:
/// - Zero BPM (resting/no signal)
/// - Normal resting HR (60 BPM)
/// - Moderate exercise HR (120 BPM)
/// - High intensity HR (200 BPM)
/// - Maximum device value (255 BPM)
/// - Edge cases and formatting
///
/// These tests verify correct rendering without requiring device or BLE connection.
void main() {
  group('HrDisplay Widget Tests', () {
    testWidgets('renders zero BPM correctly', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 0);

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      expect(find.text('0'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
      expect(find.byKey(const Key('hrDisplay')), findsOneWidget);
    });

    testWidgets('renders normal resting HR (60 BPM)', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 60);

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      expect(find.text('60'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);

      // Verify text styling
      final bpmText = tester.widget<Text>(find.text('60'));
      expect(bpmText.style?.fontSize, equals(72));
      expect(bpmText.style?.fontWeight, equals(FontWeight.bold));
      expect(bpmText.style?.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    testWidgets('renders moderate exercise HR (120 BPM)', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 120);

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      expect(find.text('120'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
    });

    testWidgets('renders high intensity HR (200 BPM)', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 200);

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      expect(find.text('200'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
    });

    testWidgets('renders maximum device value (255 BPM)', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 255);

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      expect(find.text('255'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
    });

    testWidgets('displays BPM label with correct styling', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 100);

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      final bpmLabel = tester.widget<Text>(find.text('BPM'));
      expect(bpmLabel.style?.fontSize, equals(24));
      expect(bpmLabel.style?.fontWeight, equals(FontWeight.w300));
    });

    testWidgets('uses Column layout with correct properties', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 75);

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      final column = tester.widget<Column>(find.byType(Column));
      expect(column.mainAxisSize, equals(MainAxisSize.min));
      expect(column.children.length, equals(2));
    });

    testWidgets('renders single digit BPM correctly', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 5);

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      expect(find.text('5'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
    });

    testWidgets('renders double digit BPM correctly', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 42);

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      expect(find.text('42'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
    });

    testWidgets('renders triple digit BPM correctly', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 142);

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      expect(find.text('142'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
    });

    testWidgets('uses tabular figures font feature for consistent width', (WidgetTester tester) async {
      // Arrange
      const widget1 = HrDisplay(bpm: 111);
      const widget2 = HrDisplay(bpm: 222);

      // Act
      await tester.pumpWidget(testWrapper(widget1));
      final text1 = tester.widget<Text>(find.text('111'));

      await tester.pumpWidget(testWrapper(widget2));
      final text2 = tester.widget<Text>(find.text('222'));

      // Assert - both should use tabular figures for consistent width
      expect(text1.style?.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(text2.style?.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    testWidgets('widget tree structure is correct', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 85);

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      // Verify HrDisplay widget exists
      expect(find.byType(HrDisplay), findsOneWidget);

      // Verify Column exists
      expect(find.descendant(
        of: find.byType(HrDisplay),
        matching: find.byType(Column),
      ), findsOneWidget);

      // Verify two Text widgets inside Column
      expect(find.descendant(
        of: find.byType(Column),
        matching: find.byType(Text),
      ), findsNWidgets(2));
    });

    testWidgets('updates correctly when BPM changes', (WidgetTester tester) async {
      // Arrange
      const initialBpm = 60;
      const updatedBpm = 120;

      // Act - pump initial widget
      await tester.pumpWidget(testWrapper(const HrDisplay(bpm: initialBpm)));
      expect(find.text('60'), findsOneWidget);

      // Act - pump updated widget
      await tester.pumpWidget(testWrapper(const HrDisplay(bpm: updatedBpm)));
      await tester.pump();

      // Assert - should show new BPM
      expect(find.text('120'), findsOneWidget);
      expect(find.text('60'), findsNothing);
    });

    testWidgets('renders in dark theme without errors', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 90);

      // Act
      await tester.pumpWidget(testWrapperWithTheme(
        child: widget,
        theme: ThemeData.dark(),
      ));

      // Assert
      expect(find.text('90'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
    });

    testWidgets('renders in light theme without errors', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 90);

      // Act
      await tester.pumpWidget(testWrapperWithTheme(
        child: widget,
        theme: ThemeData.light(),
      ));

      // Assert
      expect(find.text('90'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
    });

    testWidgets('boundary value: 1 BPM', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 1);

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      expect(find.text('1'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
    });

    testWidgets('boundary value: 254 BPM (one below max)', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 254);

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      expect(find.text('254'), findsOneWidget);
      expect(find.text('BPM'), findsOneWidget);
    });

    testWidgets('typical zone 1 value (50-60% max HR)', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 110); // ~55% of 200 max

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      expect(find.text('110'), findsOneWidget);
    });

    testWidgets('typical zone 2 value (60-70% max HR)', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 130); // ~65% of 200 max

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      expect(find.text('130'), findsOneWidget);
    });

    testWidgets('typical zone 3 value (70-80% max HR)', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 150); // ~75% of 200 max

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      expect(find.text('150'), findsOneWidget);
    });

    testWidgets('typical zone 4 value (80-90% max HR)', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 170); // ~85% of 200 max

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      expect(find.text('170'), findsOneWidget);
    });

    testWidgets('typical zone 5 value (90-100% max HR)', (WidgetTester tester) async {
      // Arrange
      const widget = HrDisplay(bpm: 190); // ~95% of 200 max

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert
      expect(find.text('190'), findsOneWidget);
    });
  });
}
