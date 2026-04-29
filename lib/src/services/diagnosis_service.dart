import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../bridge/api_generated.dart/api.dart';
import '../bridge/api_generated.dart/domain/heart_rate.dart';
import 'device_service.dart';
import 'log_service.dart';

/// Service for diagnosis screen operations.
///
/// Centralizes all debug/dev operations that were previously module-level
/// static functions in diagnosis_screen.dart, including BLE operations,
/// session export, and cache management.
class DiagnosisService {
  DiagnosisService._();

  static final DiagnosisService _instance = DiagnosisService._();

  static DiagnosisService get instance => _instance;

  /// Scan for BLE devices and return the list.
  Future<List<DiscoveredDevice>> scanDevices() async {
    return DeviceService.instance.scanForDevices();
  }

  /// Show device picker and connect to selected device.
  Future<String?> pickAndConnectDevice(
    BuildContext context,
    List<DiscoveredDevice> devices,
  ) async {
    final device = await showModalBottomSheet<DiscoveredDevice>(
      context: context,
      builder: (ctx) => ListView.builder(
        itemCount: devices.length,
        itemBuilder: (ctx, index) {
          final device = devices[index];
          return ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(device.name ?? 'Unknown'),
            subtitle: Text(device.id),
            onTap: () => Navigator.pop(ctx, device),
          );
        },
      ),
    );

    if (device == null) return null;
    await connectDevice(device.id);
    return device.id;
  }

  /// Connect to a device by ID.
  Future<void> connectDevice(String deviceId) async {
    await DeviceService.instance.connectDeviceById(deviceId);
  }

  /// Connect to the last known device.
  Future<void> connectLastDevice() async {
    await DeviceService.instance.connectLastDevice();
  }

  /// Disconnect from the current device.
  Future<void> disconnect() async {
    await DeviceService.instance.disconnectDevice();
  }

  /// Start mock mode for testing.
  Future<void> startMockMode() async {
    await DeviceService.instance.startMockMode();
  }

  /// Export the most recent session and share it.
  Future<void> exportAndShareLastSession() async {
    final sessions = await listSessions();
    if (sessions.isEmpty) {
      throw Exception('No sessions to export');
    }
    final lastSession = sessions.first;
    final id = await sessionPreviewId(preview: lastSession);
    final exported = await exportSession(id: id, format: ExportFormat.json);
    await Share.share(exported, subject: 'Heart Beat session export');
  }

  /// Clear log cache and reset default training plans.
  Future<void> clearCacheAndResetPlans() async {
    LogService.instance.clear();
    await seedDefaultPlans();
  }

  /// Export logs as JSON and share.
  Future<void> exportAndShareLogs() async {
    final json = LogService.instance.exportAsJson();
    await Share.share(json, subject: 'Heart Beat logs export');
  }
}