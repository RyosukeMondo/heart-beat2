import 'dart:async';
import 'dart:io' show Platform;

import 'package:permission_handler/permission_handler.dart';
import '../bridge/api_generated.dart/api.dart' as api;
import '../bridge/api_generated.dart/domain/heart_rate.dart';

/// Result of a Bluetooth permission check.
class BluetoothPermissionResult {
  final bool granted;
  final String? error;

  const BluetoothPermissionResult({required this.granted, this.error});
}

/// Service for managing Bluetooth device scanning and permissions.
///
/// This service centralizes all Bluetooth-related operations including
/// permission requests and device discovery, following the singleton pattern.
class DeviceService {
  DeviceService._();

  static final DeviceService _instance = DeviceService._();

  /// Singleton instance accessor.
  static DeviceService get instance => _instance;

  /// Stream controller for discovered devices.
  final StreamController<List<DiscoveredDevice>> _devicesController =
      StreamController<List<DiscoveredDevice>>.broadcast();

  /// Whether a scan is currently in progress.
  bool _isScanning = false;

  /// Get a broadcast stream of discovered devices.
  Stream<List<DiscoveredDevice>> get devicesStream =>
      _devicesController.stream;

  /// Check if a scan is currently in progress.
  bool get isScanning => _isScanning;

  /// Request Bluetooth permissions appropriate for the current platform.
  ///
  /// iOS requires Permission.bluetooth which triggers CBCentralManager init.
  /// Android requires bluetoothScan, bluetoothConnect, and locationWhenInUse.
  Future<BluetoothPermissionResult> requestBluetoothPermissions() async {
    try {
      final bool granted;
      if (Platform.isIOS) {
        final bluetooth = await Permission.bluetooth.request();
        granted = bluetooth.isGranted;
      } else {
        final bluetoothScan = await Permission.bluetoothScan.request();
        final bluetoothConnect = await Permission.bluetoothConnect.request();
        final location = await Permission.locationWhenInUse.request();
        granted = bluetoothScan.isGranted &&
            bluetoothConnect.isGranted &&
            location.isGranted;
      }

      return BluetoothPermissionResult(granted: granted);
    } catch (e) {
      return BluetoothPermissionResult(
        granted: false,
        error: 'Permission request failed: $e',
      );
    }
  }

  /// Scan for available Bluetooth heart rate devices.
  ///
  /// This method first requests Bluetooth permissions, then performs the scan.
  /// Results are broadcast to [devicesStream] listeners.
  ///
  /// Returns a list of discovered devices on success, or throws on failure.
  Future<List<DiscoveredDevice>> scanForDevices() async {
    if (_isScanning) {
      throw Exception('Scan already in progress');
    }

    _isScanning = true;

    try {
      // Request Bluetooth permissions
      final permResult = await requestBluetoothPermissions();
      if (!permResult.granted) {
        throw BluetoothPermissionException(permResult.error);
      }

      // Perform the scan
      final devices = await api.scanDevices();

      // Broadcast results
      _devicesController.add(devices);

      return devices;
    } finally {
      _isScanning = false;
    }
  }

  /// Connect to a specific device by ID.
  Future<void> connectDeviceById(String deviceId) async {
    await api.connectDevice(deviceId: deviceId);
  }

  /// Connect to the last known device.
  Future<void> connectLastDevice() async {
    await api.connectDevice(deviceId: 'last-connected');
  }

  /// Disconnect from the current device.
  Future<void> disconnectDevice() async {
    await api.disconnect();
  }

  /// Start mock mode for testing.
  Future<void> startMockMode() async {
    await api.startMockMode();
  }

  /// Dispose of resources.
  void dispose() {
    _devicesController.close();
  }
}

/// Exception thrown when Bluetooth permissions are not granted.
class BluetoothPermissionException implements Exception {
  final String? message;

  const BluetoothPermissionException([this.message]);

  @override
  String toString() =>
      'BluetoothPermissionException: ${message ?? 'Permissions not granted'}';
}