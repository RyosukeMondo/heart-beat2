import 'package:flutter/material.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'package:heart_beat/src/services/share_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Export menu widget for session data in multiple formats.
class SessionExportMenu extends StatelessWidget {
  final String sessionId;
  final Future<void> Function(String action) onExport;
  final bool isExporting;

  const SessionExportMenu({
    super.key,
    required this.sessionId,
    required this.onExport,
    required this.isExporting,
  });

  @override
  Widget build(BuildContext context) {
    if (isExporting) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: onExport,
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'csv',
          child: Row(
            children: [
              Icon(Icons.table_chart),
              SizedBox(width: 8),
              Text('Export as CSV'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'json',
          child: Row(
            children: [
              Icon(Icons.code),
              SizedBox(width: 8),
              Text('Export as JSON'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'tcx',
          child: Row(
            children: [
              Icon(Icons.directions_run),
              SizedBox(width: 8),
              Text('Export as TCX'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'gpx',
          child: Row(
            children: [
              Icon(Icons.map),
              SizedBox(width: 8),
              Text('Export as GPX'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'summary',
          child: Row(
            children: [
              Icon(Icons.share),
              SizedBox(width: 8),
              Text('Share Summary'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Handles exporting session data to various formats.
class SessionExporter {
  final String sessionId;

  SessionExporter({required this.sessionId});

  Future<void> exportAsCsv() async {
    final content = await exportSession(id: sessionId, format: ExportFormat.csv);
    await _shareFile(content, 'csv', 'text/csv');
  }

  Future<void> exportAsJson() async {
    final content = await exportSession(id: sessionId, format: ExportFormat.json);
    await _shareFile(content, 'json', 'application/json');
  }

  Future<void> exportAsSummary() async {
    final content = await exportSession(id: sessionId, format: ExportFormat.summary);
    await _shareText(content);
  }

  Future<void> exportAsTcx() async {
    final content = await exportSessionTcx(sessionId: sessionId);
    await _shareFile(content, 'tcx', 'application/xml');
  }

  Future<void> exportAsGpx() async {
    final content = await exportSessionGpx(sessionId: sessionId);
    await _shareFile(content, 'gpx', 'application/xml');
  }

  Future<void> _shareFile(String content, String extension, String mimeType) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'session_${sessionId}_$timestamp.$extension';
    final filePath = '${tempDir.path}/$fileName';
    final file = File(filePath);
    await file.writeAsString(content);
    await ShareService.instance.shareFile(
      filePath,
      mimeType,
      subject: 'Training Session Export',
    );
  }

  Future<void> _shareText(String content) async {
    await ShareService.instance.shareText(
      content,
      subject: 'Training Session Summary',
    );
  }
}
