import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/widgets/zone_indicator.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/domain/heart_rate.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('ZoneIndicator Widget Tests', () {
    testWidgets('displays Zone 1 with correct color and label',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        testWrapper(const ZoneIndicator(zone: Zone.zone1)),
      );

      // Assert - Widget exists
      findByKeyAndVerify('zoneIndicator');

      // Assert - Correct label
      verifyText('Zone 1 (Recovery)');

      // Assert - Correct color
      final container = tester.widget<Container>(
        find.byKey(const Key('zoneIndicator')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.border, isA<Border>());
      final border = decoration.border as Border;
      expect(border.top.color, equals(Colors.blue));

      // Assert - Text color matches zone color
      final textWidget = tester.widget<Text>(find.text('Zone 1 (Recovery)'));
      expect(textWidget.style?.color, equals(Colors.blue));
    });

    testWidgets('displays Zone 2 with correct color and label',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        testWrapper(const ZoneIndicator(zone: Zone.zone2)),
      );

      // Assert - Widget exists
      findByKeyAndVerify('zoneIndicator');

      // Assert - Correct label
      verifyText('Zone 2 (Fat Burning)');

      // Assert - Correct color
      final container = tester.widget<Container>(
        find.byKey(const Key('zoneIndicator')),
      );
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, equals(Colors.green));

      // Assert - Text color matches zone color
      final textWidget = tester.widget<Text>(find.text('Zone 2 (Fat Burning)'));
      expect(textWidget.style?.color, equals(Colors.green));
    });

    testWidgets('displays Zone 3 with correct color and label',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        testWrapper(const ZoneIndicator(zone: Zone.zone3)),
      );

      // Assert - Widget exists
      findByKeyAndVerify('zoneIndicator');

      // Assert - Correct label
      verifyText('Zone 3 (Aerobic)');

      // Assert - Correct color (yellow shade 700)
      final container = tester.widget<Container>(
        find.byKey(const Key('zoneIndicator')),
      );
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, equals(Colors.yellow.shade700));

      // Assert - Text color matches zone color
      final textWidget = tester.widget<Text>(find.text('Zone 3 (Aerobic)'));
      expect(textWidget.style?.color, equals(Colors.yellow.shade700));
    });

    testWidgets('displays Zone 4 with correct color and label',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        testWrapper(const ZoneIndicator(zone: Zone.zone4)),
      );

      // Assert - Widget exists
      findByKeyAndVerify('zoneIndicator');

      // Assert - Correct label
      verifyText('Zone 4 (Threshold)');

      // Assert - Correct color
      final container = tester.widget<Container>(
        find.byKey(const Key('zoneIndicator')),
      );
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, equals(Colors.orange));

      // Assert - Text color matches zone color
      final textWidget = tester.widget<Text>(find.text('Zone 4 (Threshold)'));
      expect(textWidget.style?.color, equals(Colors.orange));
    });

    testWidgets('displays Zone 5 with correct color and label',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        testWrapper(const ZoneIndicator(zone: Zone.zone5)),
      );

      // Assert - Widget exists
      findByKeyAndVerify('zoneIndicator');

      // Assert - Correct label
      verifyText('Zone 5 (Maximum)');

      // Assert - Correct color
      final container = tester.widget<Container>(
        find.byKey(const Key('zoneIndicator')),
      );
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, equals(Colors.red));

      // Assert - Text color matches zone color
      final textWidget = tester.widget<Text>(find.text('Zone 5 (Maximum)'));
      expect(textWidget.style?.color, equals(Colors.red));
    });

    testWidgets('zone indicator has correct dimensions',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        testWrapper(const ZoneIndicator(zone: Zone.zone3)),
      );

      // Assert - Container has width constraint of 300.0
      final container = tester.widget<Container>(
        find.byKey(const Key('zoneIndicator')),
      );
      // Width is set via constraints
      expect(container.constraints, isNotNull);
      expect(container.constraints!.maxWidth, equals(300.0));

      // Verify actual rendered width matches
      final renderBox =
          tester.renderObject<RenderBox>(find.byType(ZoneIndicator));
      expect(renderBox.size.width, equals(300.0));
    });

    testWidgets('zone indicator has correct border radius',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        testWrapper(const ZoneIndicator(zone: Zone.zone1)),
      );

      // Assert - Container has rounded corners
      final container = tester.widget<Container>(
        find.byKey(const Key('zoneIndicator')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, equals(BorderRadius.circular(12)));
    });

    testWidgets('zone indicator has correct background opacity',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        testWrapper(const ZoneIndicator(zone: Zone.zone1)),
      );

      // Assert - Background has 0.2 opacity
      final container = tester.widget<Container>(
        find.byKey(const Key('zoneIndicator')),
      );
      final decoration = container.decoration as BoxDecoration;
      final backgroundColor = decoration.color!;
      expect((backgroundColor.a * 255.0).round(), equals((0.2 * 255).round()));
    });

    testWidgets('zone indicator displays color bar',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        testWrapper(const ZoneIndicator(zone: Zone.zone2)),
      );

      // Assert - Color bar container exists with correct properties
      final zoneIndicator = find.byType(ZoneIndicator);
      expect(zoneIndicator, findsOneWidget);

      // Verify the color bar (first Container inside Column)
      final column = tester.widget<Column>(find.descendant(
        of: find.byKey(const Key('zoneIndicator')),
        matching: find.byType(Column),
      ));
      expect(column.children.length, greaterThanOrEqualTo(3));

      // The color bar is the first child (a Container)
      final firstChild = column.children[0];
      expect(firstChild, isA<Container>());
    });

    testWidgets('zone indicator text has correct styling',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        testWrapper(const ZoneIndicator(zone: Zone.zone4)),
      );

      // Assert - Text styling
      final textWidget = tester.widget<Text>(find.text('Zone 4 (Threshold)'));
      expect(textWidget.style?.fontSize, equals(18));
      expect(textWidget.style?.fontWeight, equals(FontWeight.bold));
      expect(textWidget.style?.color, equals(Colors.orange));
    });

    group('Zone transitions', () {
      testWidgets('rebuilds correctly when zone changes from zone1 to zone5',
          (WidgetTester tester) async {
        // Arrange - Start with Zone 1
        await tester.pumpWidget(
          testWrapper(const ZoneIndicator(zone: Zone.zone1)),
        );

        // Assert - Initial state
        verifyText('Zone 1 (Recovery)');
        final container1 = tester.widget<Container>(
          find.byKey(const Key('zoneIndicator')),
        );
        final decoration1 = container1.decoration as BoxDecoration;
        final border1 = decoration1.border as Border;
        expect(border1.top.color, equals(Colors.blue));

        // Act - Change to Zone 5
        await tester.pumpWidget(
          testWrapper(const ZoneIndicator(zone: Zone.zone5)),
        );
        await tester.pump();

        // Assert - Updated state
        verifyText('Zone 5 (Maximum)');
        final container5 = tester.widget<Container>(
          find.byKey(const Key('zoneIndicator')),
        );
        final decoration5 = container5.decoration as BoxDecoration;
        final border5 = decoration5.border as Border;
        expect(border5.top.color, equals(Colors.red));
      });

      testWidgets('rebuilds correctly when zone changes from zone3 to zone2',
          (WidgetTester tester) async {
        // Arrange - Start with Zone 3
        await tester.pumpWidget(
          testWrapper(const ZoneIndicator(zone: Zone.zone3)),
        );

        // Assert - Initial state
        verifyText('Zone 3 (Aerobic)');

        // Act - Change to Zone 2
        await tester.pumpWidget(
          testWrapper(const ZoneIndicator(zone: Zone.zone2)),
        );
        await tester.pump();

        // Assert - Updated state
        verifyText('Zone 2 (Fat Burning)');
        final container = tester.widget<Container>(
          find.byKey(const Key('zoneIndicator')),
        );
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        expect(border.top.color, equals(Colors.green));
      });
    });

    group('Edge cases', () {
      testWidgets('handles rapid zone changes', (WidgetTester tester) async {
        // Arrange & Act - Rapidly change zones
        await tester.pumpWidget(
          testWrapper(const ZoneIndicator(zone: Zone.zone1)),
        );
        verifyText('Zone 1 (Recovery)');

        await tester.pumpWidget(
          testWrapper(const ZoneIndicator(zone: Zone.zone3)),
        );
        await tester.pump();
        verifyText('Zone 3 (Aerobic)');

        await tester.pumpWidget(
          testWrapper(const ZoneIndicator(zone: Zone.zone5)),
        );
        await tester.pump();
        verifyText('Zone 5 (Maximum)');

        await tester.pumpWidget(
          testWrapper(const ZoneIndicator(zone: Zone.zone2)),
        );
        await tester.pump();

        // Assert - Final state is correct
        verifyText('Zone 2 (Fat Burning)');
        final container = tester.widget<Container>(
          find.byKey(const Key('zoneIndicator')),
        );
        final decoration = container.decoration as BoxDecoration;
        final border = decoration.border as Border;
        expect(border.top.color, equals(Colors.green));
      });

      testWidgets('maintains consistent layout across all zones',
          (WidgetTester tester) async {
        final zones = [
          Zone.zone1,
          Zone.zone2,
          Zone.zone3,
          Zone.zone4,
          Zone.zone5
        ];

        for (final zone in zones) {
          await tester.pumpWidget(
            testWrapper(ZoneIndicator(zone: zone)),
          );

          // Assert - Container exists and has consistent structure
          findByKeyAndVerify('zoneIndicator');
          final container = tester.widget<Container>(
            find.byKey(const Key('zoneIndicator')),
          );
          expect(container.padding, equals(const EdgeInsets.all(16)));

          // Assert - Column structure is present
          expect(find.byType(Column), findsOneWidget);
        }
      });
    });
  });
}
