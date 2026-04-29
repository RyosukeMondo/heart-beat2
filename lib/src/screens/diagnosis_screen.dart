import 'package:flutter/material.dart';
import 'diagnosis/diagnosis_body.dart';
import '../services/connection_status_service.dart';
import '../services/diagnosis_service.dart';

/// Diagnosis screen — a debug/dev surface showing live device state,
/// log viewer, and operations panel.
/// Gated on kDebugMode; production users cannot stumble into it.
class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({super.key});

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  final _svc = DiagnosisService.instance;
  final _connectionStatusProvider = ConnectionStatusServiceProvider.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('diagnosisScreen'),
      appBar: AppBar(
        title: const Text('Diagnosis'),
      ),
      body: DiagnosisBody(
        onScan: () => _handleScan(context),
        onConnectLast: () => _handleConnectLast(context),
        onDisconnect: () => _handleDisconnect(context),
        onToggleMock: () => _handleToggleMock(context),
        onExport: () => _handleExport(context),
        onClearCache: () => _handleClearCache(context),
        onDumpLogs: () => _handleDumpLogs(context),
        connectionStatusProvider: _connectionStatusProvider,
      ),
    );
  }

  Future<void> _handleScan(BuildContext context) async {
    try {
      final devices = await _svc.scanDevices();
      if (!context.mounted) return;
      await _svc.pickAndConnectDevice(context, devices);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    }
  }

  Future<void> _handleConnectLast(BuildContext context) async {
    try {
      await _svc.connectLastDevice();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connect last failed: $e')),
      );
    }
  }

  Future<void> _handleDisconnect(BuildContext context) async {
    try {
      await _svc.disconnect();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disconnect failed: $e')),
      );
    }
  }

  Future<void> _handleToggleMock(BuildContext context) async {
    try {
      await _svc.startMockMode();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mock mode failed: $e')),
      );
    }
  }

  Future<void> _handleExport(BuildContext context) async {
    try {
      await _svc.exportAndShareLastSession();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _handleClearCache(BuildContext context) async {
    try {
      await _svc.clearCacheAndResetPlans();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache cleared')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Clear cache failed: $e')),
      );
    }
  }

  Future<void> _handleDumpLogs(BuildContext context) async {
    try {
      await _svc.exportAndShareLogs();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dump logs failed: $e')),
      );
    }
  }
}