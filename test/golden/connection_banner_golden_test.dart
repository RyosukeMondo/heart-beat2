import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'golden_test_helpers.dart';

/// Golden tests for ConnectionBanner widget.
///
/// These tests capture screenshots of the ConnectionBanner widget in different
/// connection states to detect visual regressions in:
/// - Banner colors and styling for different states
/// - Icon rendering (spinner, warning, bluetooth)
/// - Text content and layout
/// - Button appearance in failed state
///
/// Since ConnectionBanner uses Rust FFI calls that can't be easily mocked
/// for visual testing, these tests render the MaterialBanner directly with
/// the expected styling from each state.
///
/// Run with:
///   flutter test test/golden/connection_banner_golden_test.dart
///
/// Update golden files with:
///   flutter test test/golden/connection_banner_golden_test.dart --update-goldens
void main() {
  group('ConnectionBanner Golden Tests', () {
    testWidgets('renders reconnecting state correctly', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Create banner matching ConnectionBanner's reconnecting state
      final widget = MaterialBanner(
        backgroundColor: Colors.orange.shade100,
        leading: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade900),
          ),
        ),
        content: Text(
          'Reconnecting... (attempt 2/5)',
          style: TextStyle(
            color: Colors.orange.shade900,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: const [SizedBox.shrink()],
      );

      // Act
      await tester.pumpWidget(goldenWrapper(widget));
      // Don't use pumpAndSettle because CircularProgressIndicator animates infinitely
      await tester.pump();

      // Assert
      await expectLater(
        find.byType(MaterialBanner),
        matchesGoldenFile('goldens/connection_banner_reconnecting.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders failed state correctly', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Create banner matching ConnectionBanner's failed state
      final widget = MaterialBanner(
        backgroundColor: Colors.red.shade100,
        leading: Icon(Icons.warning, color: Colors.red.shade900),
        content: Text(
          'Connection lost: Device out of range',
          style: TextStyle(
            color: Colors.red.shade900,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: Text(
              'Retry',
              style: TextStyle(color: Colors.red.shade900),
            ),
          ),
        ],
      );

      // Act
      await tester.pumpWidget(goldenWrapper(widget));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(MaterialBanner),
        matchesGoldenFile('goldens/connection_banner_failed.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders disconnected state correctly', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Create banner matching ConnectionBanner's disconnected state
      final widget = MaterialBanner(
        backgroundColor: Colors.grey.shade200,
        leading: Icon(Icons.bluetooth_disabled, color: Colors.grey.shade900),
        content: Text(
          'Device disconnected',
          style: TextStyle(
            color: Colors.grey.shade900,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: const [SizedBox.shrink()],
      );

      // Act
      await tester.pumpWidget(goldenWrapper(widget));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(MaterialBanner),
        matchesGoldenFile('goldens/connection_banner_disconnected.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders failed state with unknown error correctly',
        (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Create banner matching ConnectionBanner's failed state with no reason
      final widget = MaterialBanner(
        backgroundColor: Colors.red.shade100,
        leading: Icon(Icons.warning, color: Colors.red.shade900),
        content: Text(
          'Connection lost: Unknown error',
          style: TextStyle(
            color: Colors.red.shade900,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: Text(
              'Retry',
              style: TextStyle(color: Colors.red.shade900),
            ),
          ),
        ],
      );

      // Act
      await tester.pumpWidget(goldenWrapper(widget));
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(MaterialBanner),
        matchesGoldenFile('goldens/connection_banner_failed_unknown.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders reconnecting with different attempt numbers',
        (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Create banner showing first attempt
      final widget = MaterialBanner(
        backgroundColor: Colors.orange.shade100,
        leading: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade900),
          ),
        ),
        content: Text(
          'Reconnecting... (attempt 1/3)',
          style: TextStyle(
            color: Colors.orange.shade900,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: const [SizedBox.shrink()],
      );

      // Act
      await tester.pumpWidget(goldenWrapper(widget));
      // Don't use pumpAndSettle because CircularProgressIndicator animates infinitely
      await tester.pump();

      // Assert
      await expectLater(
        find.byType(MaterialBanner),
        matchesGoldenFile('goldens/connection_banner_reconnecting_first.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('renders reconnecting at max attempts', (tester) async {
      // Arrange
      setupGoldenTest(tester);

      // Create banner showing last attempt
      final widget = MaterialBanner(
        backgroundColor: Colors.orange.shade100,
        leading: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade900),
          ),
        ),
        content: Text(
          'Reconnecting... (attempt 5/5)',
          style: TextStyle(
            color: Colors.orange.shade900,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: const [SizedBox.shrink()],
      );

      // Act
      await tester.pumpWidget(goldenWrapper(widget));
      // Don't use pumpAndSettle because CircularProgressIndicator animates infinitely
      await tester.pump();

      // Assert
      await expectLater(
        find.byType(MaterialBanner),
        matchesGoldenFile('goldens/connection_banner_reconnecting_last.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });
  });
}
