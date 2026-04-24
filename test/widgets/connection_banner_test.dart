import 'dart:async';
import 'dart:ffi';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/widgets/connection_banner.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import '../helpers/test_helpers.dart';

/// Mock implementation of ApiConnectionStatus for testing.
///
/// Since ApiConnectionStatus is an opaque Rust type, we create a mock
/// that can be used in tests without requiring Rust FFI.
///
/// Note: The FFI functions (connectionStatusIsReconnecting, etc.) call into
/// Rust and do not use the Dart mock's properties. This mock is only useful
/// for testing widget tree structure and build behavior, not actual rendering.
class MockConnectionStatus implements ApiConnectionStatus {
  final ConnectionStatusType type;
  final int? attempt;
  final int? maxAttempts;
  final String? failureReason;

  MockConnectionStatus({
    required this.type,
    this.attempt,
    this.maxAttempts,
    this.failureReason,
  });

  @override
  bool get isDisposed => false;

  @override
  void dispose() {}

  Pointer<Void>? shareOrMove() => null;

  Pointer<Void>? tryShareOrMove() => null;
}

enum ConnectionStatusType {
  disconnected,
  connecting,
  connected,
  reconnecting,
  reconnectFailed,
}

/// Widget tests for ConnectionBanner component.
///
/// Tests connection status banner display including:
/// - StreamBuilder structure
/// - Widget tree composition
/// - Build behavior with various stream states
///
/// Note: Full rendering tests for different connection states require
/// Rust FFI mocking which is not available in unit tests. Visual
/// rendering is covered by golden tests instead.
void main() {
  group('ConnectionBanner Widget Tests', () {
    testWidgets('hidden when no connection status data available', (
      WidgetTester tester,
    ) async {
      // Arrange - stream with no data yet
      final controller = StreamController<ApiConnectionStatus>();
      final widget = ConnectionBanner(statusStream: controller.stream);

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert - should render nothing (SizedBox.shrink)
      expect(find.byType(MaterialBanner), findsNothing);
      expect(find.byType(ConnectionBanner), findsOneWidget);

      // Cleanup
      await controller.close();
    });

    testWidgets('widget tree structure includes StreamBuilder', (
      WidgetTester tester,
    ) async {
      // Arrange
      final controller = StreamController<ApiConnectionStatus>();
      final widget = ConnectionBanner(statusStream: controller.stream);

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert - verify widget tree structure
      expect(find.byType(ConnectionBanner), findsOneWidget);
      expect(find.byType(StreamBuilder<ApiConnectionStatus>), findsOneWidget);

      // Cleanup
      await controller.close();
    });

    testWidgets('uses custom status stream when provided', (
      WidgetTester tester,
    ) async {
      // Arrange - custom stream
      final controller = StreamController<ApiConnectionStatus>();
      final widget = ConnectionBanner(statusStream: controller.stream);

      // Act
      await tester.pumpWidget(testWrapper(widget));

      // Assert - widget should build without error
      expect(find.byType(ConnectionBanner), findsOneWidget);

      // Cleanup
      await controller.close();
    });

    testWidgets('handles rapid status changes without errors', (
      WidgetTester tester,
    ) async {
      // Arrange
      final controller = StreamController<ApiConnectionStatus>();
      final widget = ConnectionBanner(statusStream: controller.stream);

      await tester.pumpWidget(testWrapper(widget));

      // Act - emit rapid status changes
      for (int i = 0; i < 10; i++) {
        final status = MockConnectionStatus(
          type: i % 2 == 0
              ? ConnectionStatusType.reconnecting
              : ConnectionStatusType.disconnected,
          attempt: i,
          maxAttempts: 10,
        );
        controller.add(status);
        await tester.pump();
      }

      // Assert - widget should handle rapid changes without crashing
      expect(find.byType(ConnectionBanner), findsOneWidget);

      // Cleanup
      await controller.close();
    });

    testWidgets('disposed correctly when stream completes', (
      WidgetTester tester,
    ) async {
      // Arrange
      final controller = StreamController<ApiConnectionStatus>();
      final widget = ConnectionBanner(statusStream: controller.stream);

      await tester.pumpWidget(testWrapper(widget));

      // Act - complete the stream
      await controller.close();

      // Assert - widget should still exist in tree (StatelessWidget)
      expect(find.byType(ConnectionBanner), findsOneWidget);
    });

    testWidgets('uses real stream when statusStream is null', (
      WidgetTester tester,
    ) async {
      // Note: This test is skipped because ConnectionBanner with null statusStream
      // tries to use createConnectionStatusStream() which requires Rust FFI initialization.
      // In production, the widget works correctly when RustLib.init() has been called.
      // For testing purposes, we always provide a mock statusStream parameter.
    }, skip: true);
  });

  group('ConnectionBanner Integration Scenarios', () {
    testWidgets(
      'typical reconnection flow: disconnected -> reconnecting -> connected',
      (WidgetTester tester) async {
        // Arrange
        final controller = StreamController<ApiConnectionStatus>();
        final widget = ConnectionBanner(statusStream: controller.stream);

        await tester.pumpWidget(testWrapper(widget));

        // Act - simulate typical reconnection flow
        // 1. Device disconnects
        controller.add(
          MockConnectionStatus(type: ConnectionStatusType.disconnected),
        );
        await tester.pump();

        // 2. App attempts to reconnect
        for (int attempt = 1; attempt <= 3; attempt++) {
          controller.add(
            MockConnectionStatus(
              type: ConnectionStatusType.reconnecting,
              attempt: attempt,
              maxAttempts: 5,
            ),
          );
          await tester.pump();
        }

        // 3. Successfully reconnects
        controller.add(
          MockConnectionStatus(type: ConnectionStatusType.connected),
        );
        await tester.pump();

        // Assert - flow completes without errors
        expect(find.byType(ConnectionBanner), findsOneWidget);

        // Cleanup
        await controller.close();
      },
    );

    testWidgets(
      'failed reconnection flow: disconnected -> reconnecting -> failed',
      (WidgetTester tester) async {
        // Arrange
        final controller = StreamController<ApiConnectionStatus>();
        final widget = ConnectionBanner(statusStream: controller.stream);

        await tester.pumpWidget(testWrapper(widget));

        // Act - simulate failed reconnection
        // 1. Device disconnects
        controller.add(
          MockConnectionStatus(type: ConnectionStatusType.disconnected),
        );
        await tester.pump();

        // 2. Multiple reconnect attempts
        for (int attempt = 1; attempt <= 5; attempt++) {
          controller.add(
            MockConnectionStatus(
              type: ConnectionStatusType.reconnecting,
              attempt: attempt,
              maxAttempts: 5,
            ),
          );
          await tester.pump();
        }

        // 3. All attempts fail
        controller.add(
          MockConnectionStatus(
            type: ConnectionStatusType.reconnectFailed,
            failureReason: 'Maximum retry attempts exceeded',
          ),
        );
        await tester.pump();

        // Assert - flow completes without errors
        expect(find.byType(ConnectionBanner), findsOneWidget);

        // Cleanup
        await controller.close();
      },
    );

    testWidgets(
      'handles stream errors gracefully',
      (WidgetTester tester) async {
        // Arrange
        final controller = StreamController<ApiConnectionStatus>();
        final widget = ConnectionBanner(statusStream: controller.stream);

        await tester.pumpWidget(testWrapper(widget));

        // Act - add data then error
        controller.add(
          MockConnectionStatus(type: ConnectionStatusType.connected),
        );
        await tester.pump();

        controller.addError(Exception('Stream error'));
        await tester.pump();

        // Assert - widget should still be present
        expect(find.byType(ConnectionBanner), findsOneWidget);

        // Cleanup
        await controller.close();
      },
    );
  });
}
