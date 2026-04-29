import 'package:flutter/material.dart';
import '../../services/connection_status_service.dart';
import 'connection_status_card.dart';
import 'diagnosis_filter_bar_wrapper.dart';
import 'diagnosis_log_list.dart';
import 'diagnosis_operations_panel_wrapper.dart';

class DiagnosisBody extends StatefulWidget {
  final Future<void> Function() onScan;
  final Future<void> Function() onConnectLast;
  final Future<void> Function() onDisconnect;
  final Future<void> Function() onToggleMock;
  final Future<void> Function() onExport;
  final Future<void> Function() onClearCache;
  final Future<void> Function() onDumpLogs;
  final ConnectionStatusServiceProvider connectionStatusProvider;

  const DiagnosisBody({
    super.key,
    required this.onScan,
    required this.onConnectLast,
    required this.onDisconnect,
    required this.onToggleMock,
    required this.onExport,
    required this.onClearCache,
    required this.onDumpLogs,
    required this.connectionStatusProvider,
  });

  @override
  State<DiagnosisBody> createState() => _DiagnosisBodyState();
}

class _DiagnosisBodyState extends State<DiagnosisBody> {
  bool _autoScroll = true;

  void _toggleAutoScroll() {
    setState(() => _autoScroll = !_autoScroll);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DiagnosisConnectionStatusCard(
          connectionStatusProvider: widget.connectionStatusProvider,
        ),
        const Divider(height: 1),
        DiagnosisFilterBarWrapper(
          autoScroll: _autoScroll,
          onAutoScrollToggled: _toggleAutoScroll,
        ),
        const Divider(height: 1),
        Expanded(child: DiagnosisLogList(autoScroll: _autoScroll)),
        const Divider(height: 1),
        DiagnosisOperationsPanelWrapper(
          onScan: widget.onScan,
          onConnectLast: widget.onConnectLast,
          onDisconnect: widget.onDisconnect,
          onToggleMock: widget.onToggleMock,
          onExport: widget.onExport,
          onClearCache: widget.onClearCache,
          onDumpLogs: widget.onDumpLogs,
        ),
      ],
    );
  }
}