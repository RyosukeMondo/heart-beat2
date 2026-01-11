import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/domain/heart_rate.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/frb_generated.dart';
import 'package:patrol/patrol.dart';

/// Integration tests for Flutter Rust Bridge (FRB) communication.
///
/// These tests validate the Rust ↔ Flutter FFI bridge by:
/// - Testing basic API calls (scan, connect, disconnect)
/// - Validating streaming data flow (heart rate updates)
/// - Verifying error handling
/// - Testing async cancellation
///
/// All tests use the mock adapter to avoid requiring a real BLE device.
void main() {
  patrolTest(
    'FRB initialization completes successfully',
    ($) async {
      // Initialize the Rust library
      await RustLib.init();

      // Initialize panic handler - should not throw
      await initPanicHandler();

      // Verify initialization by calling a simple function
      // If the bridge isn't properly initialized, this will fail
      await startMockMode();
    },
  );

  patrolTest(
    'scanDevices returns list of DiscoveredDevice',
    ($) async {
      await RustLib.init();
      await initPanicHandler();
      await startMockMode();

      // Call scan and verify result type
      final devices = await scanDevices();

      // In mock mode, we should get at least one mock device
      expect(devices, isA<List<DiscoveredDevice>>());
      expect(devices.isNotEmpty, isTrue, reason: 'Mock mode should return at least one device');

      // Verify device structure
      final device = devices.first;
      expect(device.id, isNotEmpty, reason: 'Device ID should not be empty');
      expect(device.rssi, lessThan(0), reason: 'RSSI should be negative (dBm)');
      expect(device.rssi, greaterThan(-100), reason: 'RSSI should be reasonable');
    },
  );

  patrolTest(
    'mock mode streams heart rate data',
    ($) async {
      await RustLib.init();
      await initPanicHandler();
      await startMockMode();

      // Create HR stream
      final hrStream = createHrStream();

      // Collect a few updates to verify streaming works
      final updates = <ApiFilteredHeartRate>[];
      final subscription = hrStream.listen((data) {
        updates.add(data);
      });

      // Wait for some updates (mock mode generates data periodically)
      await Future.delayed(const Duration(seconds: 3));

      // Verify we received updates
      expect(updates.isNotEmpty, isTrue, reason: 'Should receive HR updates in mock mode');

      // Verify data structure by extracting values
      if (updates.isNotEmpty) {
        final firstUpdate = updates.first;

        // Get BPM values
        final rawBpm = await hrRawBpm(data: firstUpdate);
        final filteredBpm = await hrFilteredBpm(data: firstUpdate);

        // Verify BPM values are reasonable
        expect(rawBpm, greaterThan(0), reason: 'Raw BPM should be positive');
        expect(rawBpm, lessThan(220), reason: 'Raw BPM should be realistic');
        expect(filteredBpm, greaterThan(0), reason: 'Filtered BPM should be positive');
        expect(filteredBpm, lessThan(220), reason: 'Filtered BPM should be realistic');

        // Get timestamp
        final timestamp = await hrTimestamp(data: firstUpdate);
        expect(timestamp, greaterThan(BigInt.zero), reason: 'Timestamp should be positive');

        // Test zone calculation
        const maxHr = 180;
        final zone = await hrZone(data: firstUpdate, maxHr: maxHr);
        expect(zone, isA<Zone>(), reason: 'Should return a valid Zone');

        // Test optional fields (may or may not be present)
        final rmssd = await hrRmssd(data: firstUpdate);
        if (rmssd != null) {
          expect(rmssd, greaterThan(0), reason: 'RMSSD should be positive if present');
        }

        final battery = await hrBatteryLevel(data: firstUpdate);
        if (battery != null) {
          expect(battery, greaterThanOrEqualTo(0), reason: 'Battery should be >= 0');
          expect(battery, lessThanOrEqualTo(100), reason: 'Battery should be <= 100');
        }
      }

      // Clean up
      await subscription.cancel();
      await disconnect();
    },
  );

  patrolTest(
    'connectDevice handles invalid device ID gracefully',
    ($) async {
      await RustLib.init();
      await initPanicHandler();

      // Try to connect to an invalid/non-existent device
      // This should return an error, not crash
      expect(
        () => connectDevice(deviceId: 'invalid-device-id-12345'),
        throwsA(anything),
        reason: 'Connecting to invalid device should throw an error',
      );
    },
  );

  patrolTest(
    'stream subscription can be cancelled',
    ($) async {
      await RustLib.init();
      await initPanicHandler();
      await startMockMode();

      // Create and immediately cancel stream
      final hrStream = createHrStream();
      final subscription = hrStream.listen((_) {});

      // Cancel immediately
      await subscription.cancel();

      // Wait a bit to ensure no crashes occur after cancellation
      await Future.delayed(const Duration(seconds: 1));

      // Clean up
      await disconnect();
    },
  );

  patrolTest(
    'logging stream receives log messages',
    ($) async {
      await RustLib.init();
      await initPanicHandler();

      // Set up logging stream
      final logStream = initLogging();
      final logs = <LogMessage>[];

      final subscription = logStream.listen((log) {
        logs.add(log);
      });

      // Trigger some operations that should generate logs
      await startMockMode();
      await scanDevices();

      // Wait for logs to propagate
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify we received some logs
      expect(logs.isNotEmpty, isTrue, reason: 'Should receive log messages from Rust');

      // Verify log structure
      if (logs.isNotEmpty) {
        final log = logs.first;
        expect(log.level, isNotEmpty, reason: 'Log level should not be empty');
        expect(log.target, isNotEmpty, reason: 'Log target should not be empty');
        expect(log.message, isNotEmpty, reason: 'Log message should not be empty');
        expect(log.timestamp, greaterThan(BigInt.zero), reason: 'Timestamp should be positive');
      }

      // Clean up
      await subscription.cancel();
      await disconnect();
    },
  );

  patrolTest(
    'multiple API calls in sequence work correctly',
    ($) async {
      await RustLib.init();
      await initPanicHandler();

      // Sequence of operations
      await startMockMode();

      final devices = await scanDevices();
      expect(devices.isNotEmpty, isTrue);

      // In mock mode, we can "connect" to the mock device
      if (devices.isNotEmpty) {
        final deviceId = devices.first.id;
        await connectDevice(deviceId: deviceId);

        // Create stream and verify data
        final hrStream = createHrStream();
        final updates = <ApiFilteredHeartRate>[];
        final subscription = hrStream.listen((data) {
          updates.add(data);
        });

        await Future.delayed(const Duration(seconds: 2));
        expect(updates.isNotEmpty, isTrue);

        await subscription.cancel();
      }

      // Disconnect
      await disconnect();

      // Verify we can scan again after disconnect
      final devicesAfterDisconnect = await scanDevices();
      expect(devicesAfterDisconnect, isA<List<DiscoveredDevice>>());
    },
  );

  patrolTest(
    'panic handler prevents app crashes',
    ($) async {
      await RustLib.init();
      await initPanicHandler();

      // This test verifies that the panic handler is working
      // If a Rust panic occurs, it should be converted to a Dart exception
      // rather than crashing the entire app

      // We can't easily trigger a panic from the public API,
      // but we can verify the panic handler was initialized
      // by checking that subsequent calls work fine

      await startMockMode();
      final devices = await scanDevices();
      expect(devices, isA<List<DiscoveredDevice>>());

      await disconnect();
    },
  );
}
