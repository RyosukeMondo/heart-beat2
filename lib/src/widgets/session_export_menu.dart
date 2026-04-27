import 'package:flutter/material.dart';

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
