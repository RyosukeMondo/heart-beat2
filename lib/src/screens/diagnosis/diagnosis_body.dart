import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/diagnosis_log_service.dart';
import 'connection_status_card.dart';
import 'filter_bar.dart';
import 'log_line.dart';
import 'operations_panel.dart';

class DiagnosisBody extends StatelessWidget {
  final Future<void> Function() onScan;
  final Future<void> Function() onConnectLast;
  final Future<void> Function() onDisconnect;
  final Future<void> Function() onToggleMock;
  final Future<void> Function() onExport;
  final Future<void> Function() onClearCache;

  const DiagnosisBody({
    super.key,
    required this.onScan,
    required this.onConnectLast,
    required this.onDisconnect,
    required this.onToggleMock,
    required this.onExport,
    required this.onClearCache,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const DiagnosisConnectionStatusCard(),
        const Divider(height: 1),
        const _DiagnosisFilterBarWrapper(),
        const Divider(height: 1),
        const Expanded(child: _DiagnosisLogList()),
        const Divider(height: 1),
        _DiagnosisOperationsPanelWrapper(onScan: onScan, onConnectLast: onConnectLast, onDisconnect: onDisconnect, onToggleMock: onToggleMock, onExport: onExport, onClearCache: onClearCache),
      ],
    );
  }
}

class _DiagnosisFilterBarWrapper extends StatelessWidget {
  const _DiagnosisFilterBarWrapper();

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<DiagnosisLogService>();

    return DiagnosisFilterBar(
      sourceFilter: svc.sourceFilter,
      levelFilter: svc.levelFilter,
      searchController: TextEditingController(text: svc.searchQuery),
      autoScroll: svc.autoScroll,
      onSourceChanged: (v) => svc.setSourceFilter(v),
      onLevelChanged: (v) => svc.setLevelFilter(v),
      onSearchChanged: (v) => svc.setSearchQuery(v),
      onAutoScrollToggled: () => svc.toggleAutoScroll(),
      onClearPinned: () {},
    );
  }
}

class _DiagnosisLogList extends StatelessWidget {
  const _DiagnosisLogList();

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<DiagnosisLogService>();
    final allLogs = svc.logs;
    final filtered = svc.filterLogs(allLogs);
    final pinnedIndex = svc.pinnedIndex;

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          allLogs.isEmpty
              ? 'No logs yet'
              : 'No logs match filters',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return ListView.builder(
      controller: svc.scrollController,
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final log = filtered[index];
        final isPinned = pinnedIndex == index;
        return DiagnosisLogLine(
          log: log,
          levelColor: svc.levelColor(log.level),
          isPinned: isPinned,
          onTap: () => svc.togglePinned(index),
        );
      },
    );
  }
}

class _DiagnosisOperationsPanelWrapper extends StatefulWidget {
  final Future<void> Function() onScan;
  final Future<void> Function() onConnectLast;
  final Future<void> Function() onDisconnect;
  final Future<void> Function() onToggleMock;
  final Future<void> Function() onExport;
  final Future<void> Function() onClearCache;

  const _DiagnosisOperationsPanelWrapper({
    required this.onScan,
    required this.onConnectLast,
    required this.onDisconnect,
    required this.onToggleMock,
    required this.onExport,
    required this.onClearCache,
  });

  @override
  State<_DiagnosisOperationsPanelWrapper> createState() => _DiagnosisOperationsPanelWrapperState();
}

class _DiagnosisOperationsPanelWrapperState extends State<_DiagnosisOperationsPanelWrapper> {
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
