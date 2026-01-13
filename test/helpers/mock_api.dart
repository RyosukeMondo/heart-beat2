import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/domain/heart_rate.dart';

/// Mock implementations of Rust FFI API for widget testing.
///
/// These mocks allow widgets to be tested without requiring:
/// - Rust FFI initialization
/// - Bluetooth hardware
/// - Device/emulator
///
/// Usage in tests:
/// ```dart
/// // Mock the listPlans function
/// final mockPlans = MockPlans(plans: ['Plan A', 'Plan B']);
/// // Pass mock data to widgets or use in test setup
/// ```

/// Mock plans data for testing PlanSelector widget.
class MockPlans {
  final List<String> plans;
  final String? error;

  MockPlans({
    this.plans = const [],
    this.error,
  });

  /// Simulates successful plan listing.
  static MockPlans success(List<String> plans) {
    return MockPlans(plans: plans);
  }

  /// Simulates error during plan listing.
  static MockPlans failure(String error) {
    return MockPlans(error: error);
  }

  /// Simulates empty plan list.
  static MockPlans empty() {
    return MockPlans(plans: []);
  }

  /// Default mock with sample plans.
  static MockPlans get defaultPlans => MockPlans(
        plans: ['Beginner 5K', 'Marathon Training', 'HIIT Intervals'],
      );
}

/// Mock discovered devices for testing device scanning widgets.
class MockDevices {
  /// Creates a mock discovered device.
  static DiscoveredDevice device({
    required String id,
    String? name,
    int rssi = -60,
  }) {
    return DiscoveredDevice(
      id: id,
      name: name,
      rssi: rssi,
    );
  }

  /// Default mock device list.
  static List<DiscoveredDevice> get defaultDevices => [
        device(id: 'device1', name: 'Polar H10', rssi: -55),
        device(id: 'device2', name: 'Garmin HRM', rssi: -65),
        device(id: 'device3', name: 'Wahoo TICKR', rssi: -70),
      ];

  /// Empty device list (no devices found).
  static List<DiscoveredDevice> get empty => [];
}

/// Mock zone data for testing zone-related widgets.
class MockZone {
  /// All possible heart rate zones.
  static const zones = [
    Zone.zone1,
    Zone.zone2,
    Zone.zone3,
    Zone.zone4,
    Zone.zone5,
  ];

  /// Zone names for display.
  static String zoneName(Zone zone) {
    switch (zone) {
      case Zone.zone1:
        return 'Zone 1';
      case Zone.zone2:
        return 'Zone 2';
      case Zone.zone3:
        return 'Zone 3';
      case Zone.zone4:
        return 'Zone 4';
      case Zone.zone5:
        return 'Zone 5';
    }
  }

  /// Zone colors for testing visual output.
  static Map<Zone, String> get zoneColors => {
        Zone.zone1: 'gray',
        Zone.zone2: 'blue',
        Zone.zone3: 'green',
        Zone.zone4: 'yellow',
        Zone.zone5: 'red',
      };
}

/// Mock battery levels for testing battery indicator widget.
///
/// Note: ApiBatteryLevel constructor requires isCharging and timestamp.
class MockBattery {
  /// Creates a battery level reading.
  static ApiBatteryLevel withLevel(int? level, {bool isCharging = false}) {
    return ApiBatteryLevel(
      level: level,
      isCharging: isCharging,
      timestamp: BigInt.from(DateTime.now().millisecondsSinceEpoch),
    );
  }

  /// Full battery (100%).
  static ApiBatteryLevel get full => withLevel(100);

  /// High battery (75%).
  static ApiBatteryLevel get high => withLevel(75);

  /// Medium battery (50%).
  static ApiBatteryLevel get medium => withLevel(50);

  /// Low battery (25%).
  static ApiBatteryLevel get low => withLevel(25);

  /// Critical battery (10%).
  static ApiBatteryLevel get critical => withLevel(10);

  /// Empty battery (0%).
  static ApiBatteryLevel get empty => withLevel(0);

  /// Charging battery.
  static ApiBatteryLevel get charging => withLevel(50, isCharging: true);
}
