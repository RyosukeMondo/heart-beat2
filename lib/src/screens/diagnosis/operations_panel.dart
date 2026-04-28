import 'package:flutter/material.dart';

class DiagnosisOperationsPanel extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onConnectLast;
  final VoidCallback onDisconnect;
  final VoidCallback onToggleMock;
  final VoidCallback onExport;
  final VoidCallback onClearCache;
  final VoidCallback onDumpLogs;
  final bool mockActive;
  final ValueChanged<bool> onMockActiveChanged;

  const DiagnosisOperationsPanel({
    super.key,
    required this.onScan,
    required this.onConnectLast,
    required this.onDisconnect,
    required this.onToggleMock,
    required this.onExport,
    required this.onClearCache,
    required this.onDumpLogs,
    required this.mockActive,
    required this.onMockActiveChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _DiagnosisOpButton(
            icon: Icons.bluetooth_searching,
            label: 'Scan',
            onPressed: onScan,
          ),
          _DiagnosisOpButton(
            icon: Icons.history,
            label: 'Connect Last',
            onPressed: onConnectLast,
          ),
          _DiagnosisOpButton(
            icon: Icons.bluetooth_disabled,
            label: 'Disconnect',
            onPressed: onDisconnect,
          ),
          _DiagnosisOpButton(
            icon: Icons.science,
            label: 'Mock',
            onPressed: onToggleMock,
          ),
          _DiagnosisOpButton(
            icon: Icons.ios_share,
            label: 'Export',
            onPressed: onExport,
          ),
          _DiagnosisOpButton(
            icon: Icons.delete_sweep,
            label: 'Clear Cache',
            onPressed: onClearCache,
          ),
          _DiagnosisOpButton(
            icon: Icons.download,
            label: 'Dump Logs',
            onPressed: onDumpLogs,
          ),
        ],
      ),
    );
  }
}

class _DiagnosisOpButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _DiagnosisOpButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
