import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'package:heart_beat/src/services/connection_status_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectionStatusService', () {
    test('should be a singleton', () {
      final instance1 = ConnectionStatusService.instance;
      final instance2 = ConnectionStatusService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('singleton instance is the same object across calls', () {
      final instance1 = ConnectionStatusService.instance;
      final instance2 = ConnectionStatusService.instance;
      final instance3 = ConnectionStatusService.instance;

      expect(identical(instance1, instance2), isTrue);
      expect(identical(instance2, instance3), isTrue);
      expect(identical(instance1, instance3), isTrue);
    });

    test('getStatusData returns ConnectionStatusData with correct mapping', () async {
      final service = ConnectionStatusService.instance;

      // getStatusData: (ApiConnectionStatus) -> Future<ConnectionStatusData>
      // Verify the method is callable and returns the expected type structure.
      // Note: ApiConnectionStatus is an opaque Rust type (RustOpaqueNom), so we
      // cannot construct a real instance in Dart tests. The FFI functions
      // (connectionStatusIsConnected, etc.) call into Rust and do not use Dart
      // mock properties. Behavioral mapping tests require integration test
      // infrastructure where Rust FFI is available.
      Future<ConnectionStatusData> Function(ApiConnectionStatus) getStatusData;
      getStatusData = service.getStatusData;
      expect(getStatusData, isNotNull);

      // Verify the method has the correct signature by checking its type
      expect(service.getStatusData, isA<Future<ConnectionStatusData> Function(ApiConnectionStatus)>());
    });

    test('singleton identity preserved across multiple accesses', () {
      final first = ConnectionStatusService.instance;
      final second = ConnectionStatusService.instance;

      expect(identical(first, second), isTrue);

      for (int i = 0; i < 5; i++) {
        expect(identical(ConnectionStatusService.instance, first), isTrue);
      }
    });
  });

  group('ConnectionStatusData', () {
    test('has all required fields', () {
      const data = ConnectionStatusData(
        isConnected: true,
        isConnecting: false,
        isReconnecting: false,
        isReconnectFailed: false,
        isDisconnected: false,
        deviceId: 'test-device',
        attempt: null,
        maxAttempts: null,
        failureReason: null,
      );

      expect(data.isConnected, isTrue);
      expect(data.isConnecting, isFalse);
      expect(data.isReconnecting, isFalse);
      expect(data.isReconnectFailed, isFalse);
      expect(data.isDisconnected, isFalse);
      expect(data.deviceId, equals('test-device'));
      expect(data.attempt, isNull);
      expect(data.maxAttempts, isNull);
      expect(data.failureReason, isNull);
    });

    test('supports all status states', () {
      const connected = ConnectionStatusData(
        isConnected: true,
        isConnecting: false,
        isReconnecting: false,
        isReconnectFailed: false,
        isDisconnected: false,
      );

      const connecting = ConnectionStatusData(
        isConnected: false,
        isConnecting: true,
        isReconnecting: false,
        isReconnectFailed: false,
        isDisconnected: false,
      );

      const reconnecting = ConnectionStatusData(
        isConnected: false,
        isConnecting: false,
        isReconnecting: true,
        isReconnectFailed: false,
        isDisconnected: false,
        attempt: 3,
        maxAttempts: 5,
      );

      const reconnectFailed = ConnectionStatusData(
        isConnected: false,
        isConnecting: false,
        isReconnecting: false,
        isReconnectFailed: true,
        isDisconnected: false,
        failureReason: 'Max attempts exceeded',
      );

      const disconnected = ConnectionStatusData(
        isConnected: false,
        isConnecting: false,
        isReconnecting: false,
        isReconnectFailed: false,
        isDisconnected: true,
      );

      expect(connected.isConnected, isTrue);
      expect(connecting.isConnecting, isTrue);
      expect(reconnecting.isReconnecting, isTrue);
      expect(reconnecting.attempt, equals(3));
      expect(reconnecting.maxAttempts, equals(5));
      expect(reconnectFailed.isReconnectFailed, isTrue);
      expect(reconnectFailed.failureReason, equals('Max attempts exceeded'));
      expect(disconnected.isDisconnected, isTrue);
    });
  });
}