import 'package:flutter/material.dart';
import '../bridge/api_generated.dart/api.dart';
import '../bridge/api_generated.dart/domain/heart_rate.dart';
import 'diagnosis/diagnosis_body.dart';
import '../services/log_service.dart';
import 'package:share_plus/share_plus.dart';

/// Diagnosis screen — a debug/dev surface showing live device state,
/// log viewer, and operations panel.
/// Gated on kDebugMode; production users cannot stumble into it.
class DiagnosisScreen extends StatelessWidget {
  const DiagnosisScreen({super.key});

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
      ),
    );
  }
}

Future<void> _handleScan(BuildContext context) async {
  try {
    final devices = await scanDevices();
    if (!context.mounted) return;
    _showDevicePicker(context, devices);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Scan failed: $e')),
    );
  }
}

void _showDevicePicker(BuildContext context, List<DiscoveredDevice> devices) {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => ListView.builder(
      itemCount: devices.length,
      itemBuilder: (ctx, index) {
        final device = devices[index];
        return ListTile(
          leading: const Icon(Icons.bluetooth),
          title: Text(device.name ?? 'Unknown'),
          subtitle: Text(device.id),
          onTap: () async {
            Navigator.pop(ctx);
            try {
              await connectDevice(deviceId: device.id);
            } catch (e) {
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(content: Text('Connect failed: $e')),
              );
            }
          },
        );
      },
    ),
  );
}

Future<void> _handleConnectLast(BuildContext context) async {
  try {
    await connectDevice(deviceId: 'last-connected');
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connect last failed: $e')),
    );
  }
}

Future<void> _handleDisconnect(BuildContext context) async {
  try {
    await disconnect();
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Disconnect failed: $e')),
    );
  }
}

Future<void> _handleToggleMock(BuildContext context) async {
  try {
    await startMockMode();
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Mock mode failed: $e')),
    );
  }
}

Future<void> _handleExport(BuildContext context) async {
  try {
    final sessions = await listSessions();
    if (sessions.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No sessions to export')),
      );
      return;
    }
    final lastSession = sessions.first;
    final id = await sessionPreviewId(preview: lastSession);
    final exported = await exportSession(id: id, format: ExportFormat.json);
    await Share.share(exported, subject: 'Heart Beat session export');
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export failed: $e')),
    );
  }
}

Future<void> _handleClearCache(BuildContext context) async {
  try {
    LogService.instance.clear();
    await seedDefaultPlans();
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
