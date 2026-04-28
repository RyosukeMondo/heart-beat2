import 'package:flutter/material.dart';
import 'operations_panel.dart';

class DiagnosisOperationsPanelWrapper extends StatefulWidget {
  final Future<void> Function() onScan;
  final Future<void> Function() onConnectLast;
  final Future<void> Function() onDisconnect;
  final Future<void> Function() onToggleMock;
  final Future<void> Function() onExport;
  final Future<void> Function() onClearCache;

  const DiagnosisOperationsPanelWrapper({
    super.key,
    required this.onScan,
    required this.onConnectLast,
    required this.onDisconnect,
    required this.onToggleMock,
    required this.onExport,
    required this.onClearCache,
  });

  @override
  State<DiagnosisOperationsPanelWrapper> createState() =>
      _DiagnosisOperationsPanelWrapperState();
}

class _DiagnosisOperationsPanelWrapperState
    extends State<DiagnosisOperationsPanelWrapper> {
  bool _mockActive = false;

  @override
  Widget build(BuildContext context) {
    return DiagnosisOperationsPanel(
      onScan: widget.onScan,
      onConnectLast: widget.onConnectLast,
      onDisconnect: widget.onDisconnect,
      onToggleMock: () async {
        await widget.onToggleMock();
        setState(() => _mockActive = !_mockActive);
      },
      onExport: widget.onExport,
      onClearCache: widget.onClearCache,
      mockActive: _mockActive,
      onMockActiveChanged: (v) => setState(() => _mockActive = v),
    );
  }
}