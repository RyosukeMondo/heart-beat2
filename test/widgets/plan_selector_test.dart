import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/widgets/plan_selector.dart';
import '../helpers/test_helpers.dart';

/// Create a bottom sheet wrapper with larger test surface to avoid overflow
Widget bottomSheetWrapperLarge({
  required WidgetBuilder builder,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        return MediaQuery(
          data: const MediaQueryData(size: Size(800, 1200)),
          child: Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: builder,
                    isScrollControlled: true,
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Widget tests for PlanSelector component.
///
/// Tests plan list rendering, selection callbacks, and error states including:
/// - Plan list display with multiple plans
/// - Plan selection callback firing with correct plan name
/// - Empty state when no plans available
/// - Error state when plan loading fails
/// - Loading state during async plan fetch
/// - Retry functionality on error
///
/// These tests verify correct rendering and behavior without requiring Rust FFI.
void main() {
  group('PlanSelector Widget Tests', () {
    testWidgets('renders loading state initially', (WidgetTester tester) async {
      // Arrange
      final widget = PlanSelector(
        onSelect: (_) {},
        planLoader: () async {
          // Delay to keep widget in loading state
          await Future.delayed(const Duration(milliseconds: 100));
          return ['Plan A', 'Plan B'];
        },
      );

      // Act
      await tester.pumpWidget(bottomSheetWrapper(
        builder: (context) => widget,
      ));
      await tester.tap(find.text('Show'));
      await tester.pump();

      // Assert - should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Cleanup - let the async operation complete
      await tester.pumpAndSettle();
    });

    testWidgets('renders plan list after loading', (WidgetTester tester) async {
      // Arrange
      final plans = ['5K Training', 'Marathon Prep', 'Base Building'];
      final widget = PlanSelector(
        onSelect: (_) {},
        planLoader: () async => plans,
      );

      // Act
      await tester.pumpWidget(bottomSheetWrapper(
        builder: (context) => widget,
      ));
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Assert - should show all plans
      expect(find.text('5K Training'), findsOneWidget);
      expect(find.text('Marathon Prep'), findsOneWidget);
      expect(find.text('Base Building'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('calls onSelect callback when plan is tapped', (WidgetTester tester) async {
      // Arrange
      final callback = MockCallback<String>();
      final plans = ['Plan A', 'Plan B', 'Plan C'];
      final widget = PlanSelector(
        onSelect: callback.call,
        planLoader: () async => plans,
      );

      // Act
      await tester.pumpWidget(bottomSheetWrapper(
        builder: (context) => widget,
      ));
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Tap on "Plan B"
      await tester.tap(find.text('Plan B'));
      await tester.pumpAndSettle();

      // Assert - callback should be called with "Plan B"
      expect(callback.called, isTrue);
      expect(callback.lastArg, equals('Plan B'));
      expect(callback.callCount, equals(1));
    });

    testWidgets('closes bottom sheet after plan selection', (WidgetTester tester) async {
      // Arrange
      final plans = ['Quick Plan'];
      final widget = PlanSelector(
        onSelect: (_) {},
        planLoader: () async => plans,
      );

      // Act
      await tester.pumpWidget(bottomSheetWrapper(
        builder: (context) => widget,
      ));
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Verify bottom sheet is open
      expect(find.text('Quick Plan'), findsOneWidget);
      expect(find.text('Select Training Plan'), findsOneWidget);

      // Tap plan
      await tester.tap(find.text('Quick Plan'));
      await tester.pumpAndSettle();

      // Assert - bottom sheet should be closed
      expect(find.text('Quick Plan'), findsNothing);
      expect(find.text('Select Training Plan'), findsNothing);
    });

    testWidgets('renders empty state when no plans available', (WidgetTester tester) async {
      // Arrange
      final widget = PlanSelector(
        onSelect: (_) {},
        planLoader: () async => [],
      );

      // Act
      await tester.pumpWidget(bottomSheetWrapperLarge(
        builder: (context) => widget,
      ));
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Assert - should show empty state
      expect(find.text('No Plans Found'), findsOneWidget);
      expect(find.text('Training plans should be placed in:\n~/.heart-beat/plans/'), findsOneWidget);
      expect(find.byIcon(Icons.folder_open), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('renders error state when plan loading fails', (WidgetTester tester) async {
      // Arrange
      final widget = PlanSelector(
        onSelect: (_) {},
        planLoader: () async {
          throw Exception('Failed to load plans from filesystem');
        },
      );

      // Act
      await tester.pumpWidget(bottomSheetWrapperLarge(
        builder: (context) => widget,
      ));
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Assert - should show error state
      expect(find.text('Failed to load plans'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Exception: Failed to load plans from filesystem'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('retry button reloads plans after error', (WidgetTester tester) async {
      // Arrange
      int attemptCount = 0;
      final widget = PlanSelector(
        onSelect: (_) {},
        planLoader: () async {
          attemptCount++;
          if (attemptCount == 1) {
            throw Exception('Network error');
          }
          return ['Recovered Plan'];
        },
      );

      // Act
      await tester.pumpWidget(bottomSheetWrapperLarge(
        builder: (context) => widget,
      ));
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Assert - should show error first
      expect(find.text('Failed to load plans'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Tap retry button
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      // Assert - should show plans after retry
      expect(find.text('Recovered Plan'), findsOneWidget);
      expect(find.text('Failed to load plans'), findsNothing);
      expect(attemptCount, equals(2));
    });

    testWidgets('renders title and icon correctly', (WidgetTester tester) async {
      // Arrange
      final widget = PlanSelector(
        onSelect: (_) {},
        planLoader: () async => ['Test Plan'],
      );

      // Act
      await tester.pumpWidget(bottomSheetWrapper(
        builder: (context) => widget,
      ));
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Assert - should show title with icon
      expect(find.text('Select Training Plan'), findsOneWidget);
      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
    });

    testWidgets('renders ListTile with correct icons for each plan', (WidgetTester tester) async {
      // Arrange
      final plans = ['Plan 1', 'Plan 2'];
      final widget = PlanSelector(
        onSelect: (_) {},
        planLoader: () async => plans,
      );

      // Act
      await tester.pumpWidget(bottomSheetWrapper(
        builder: (context) => widget,
      ));
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Assert - each plan should have ListTile with icons
      expect(find.byType(ListTile), findsNWidgets(2));
      expect(find.byIcon(Icons.directions_run), findsNWidgets(2));
      expect(find.byIcon(Icons.arrow_forward_ios), findsNWidgets(2));
      expect(find.byType(CircleAvatar), findsNWidgets(2));
    });

    testWidgets('handles single plan correctly', (WidgetTester tester) async {
      // Arrange
      final callback = MockCallback<String>();
      final widget = PlanSelector(
        onSelect: callback.call,
        planLoader: () async => ['Only Plan'],
      );

      // Act
      await tester.pumpWidget(bottomSheetWrapper(
        builder: (context) => widget,
      ));
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Only Plan'), findsOneWidget);
      expect(find.byType(ListTile), findsOneWidget);

      // Tap the plan
      await tester.tap(find.text('Only Plan'));
      await tester.pumpAndSettle();

      expect(callback.lastArg, equals('Only Plan'));
    });

    testWidgets('handles many plans with scrolling', (WidgetTester tester) async {
      // Arrange
      final plans = List.generate(20, (i) => 'Plan ${i + 1}');
      final widget = PlanSelector(
        onSelect: (_) {},
        planLoader: () async => plans,
      );

      // Act
      await tester.pumpWidget(bottomSheetWrapper(
        builder: (context) => widget,
      ));
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Assert - should render ListView with plans
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Plan 1'), findsOneWidget);

      // Verify multiple ListTiles exist (not all may be visible, but some should be)
      expect(find.byType(ListTile), findsWidgets);
    });

    testWidgets('multiple selections fire callback each time', (WidgetTester tester) async {
      // Arrange
      final callback = MockCallback<String>();
      final plans = ['Plan A', 'Plan B'];

      // Act & Assert - First selection
      await tester.pumpWidget(bottomSheetWrapper(
        builder: (context) => PlanSelector(
          onSelect: callback.call,
          planLoader: () async => plans,
        ),
      ));
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan A'));
      await tester.pumpAndSettle();

      expect(callback.callCount, equals(1));
      expect(callback.lastArg, equals('Plan A'));

      // Act & Assert - Second selection (reopen sheet)
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan B'));
      await tester.pumpAndSettle();

      expect(callback.callCount, equals(2));
      expect(callback.lastArg, equals('Plan B'));
    });

    testWidgets('plan names with special characters render correctly', (WidgetTester tester) async {
      // Arrange
      final plans = [
        '5K-Fast-Finish',
        'Marathon_2024',
        'Half-Marathon (Beginner)',
      ];
      final widget = PlanSelector(
        onSelect: (_) {},
        planLoader: () async => plans,
      );

      // Act
      await tester.pumpWidget(bottomSheetWrapper(
        builder: (context) => widget,
      ));
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Assert - all special character names should display
      expect(find.text('5K-Fast-Finish'), findsOneWidget);
      expect(find.text('Marathon_2024'), findsOneWidget);
      expect(find.text('Half-Marathon (Beginner)'), findsOneWidget);
    });

    testWidgets('widget tree structure is correct', (WidgetTester tester) async {
      // Arrange
      final widget = PlanSelector(
        onSelect: (_) {},
        planLoader: () async => ['Plan'],
      );

      // Act
      await tester.pumpWidget(bottomSheetWrapper(
        builder: (context) => widget,
      ));
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Assert - verify widget tree structure
      expect(find.byType(PlanSelector), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(find.byType(Column), findsWidgets);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('loading state shows only spinner, no plans', (WidgetTester tester) async {
      // Arrange
      final widget = PlanSelector(
        onSelect: (_) {},
        planLoader: () async {
          // Short delay to test loading state
          await Future.delayed(const Duration(milliseconds: 50));
          return ['Plan'];
        },
      );

      // Act
      await tester.pumpWidget(bottomSheetWrapper(
        builder: (context) => widget,
      ));
      await tester.tap(find.text('Show'));
      await tester.pump(); // Pump once to show loading state
      await tester.pump(const Duration(milliseconds: 10)); // Pump a bit more

      // Assert - only loading indicator, no content yet
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);

      // Cleanup - let async operation complete
      await tester.pumpAndSettle();
    });

    testWidgets('error message displays full exception text', (WidgetTester tester) async {
      // Arrange
      final errorMessage = 'File not found';
      final widget = PlanSelector(
        onSelect: (_) {},
        planLoader: () async {
          throw Exception(errorMessage);
        },
      );

      // Act
      await tester.pumpWidget(bottomSheetWrapperLarge(
        builder: (context) => widget,
      ));
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Assert - full error message should be visible
      expect(find.text('Exception: $errorMessage'), findsOneWidget);
    });
  });
}
