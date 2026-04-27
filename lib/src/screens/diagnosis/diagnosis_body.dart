import 'package:flutter/material.dart';
import '../../bridge/api_generated.dart/api.dart';
import '../../services/log_service.dart';
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
        Expanded(child: _DiagnosisLogList()),
        const Divider(height: 1),
        _DiagnosisOperationsPanelWrapper(onScan: onScan, onConnectLast: onConnectLast, onDisconnect: onDisconnect, onToggleMock: onToggleMock, onExport: onExport, onClearCache: onClearCache),
      ],
    );
  }
}

class _DiagnosisFilterBarWrapper extends StatefulWidget {
  const _DiagnosisFilterBarWrapper();

  @override
  State<_DiagnosisFilterBarWrapper> createState() => _DiagnosisFilterBarWrapperState();
}

class _DiagnosisFilterBarWrapperState extends State<_DiagnosisFilterBarWrapper> {
  String? _sourceFilter;
  String? _levelFilter;
  final TextEditingController _searchController = TextEditingController();
  bool _autoScroll = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DiagnosisFilterBar(
      sourceFilter: _sourceFilter,
      levelFilter: _levelFilter,
      searchController: _searchController,
      autoScroll: _autoScroll,
      onSourceChanged: (v) => setState(() => _sourceFilter = v),
      onLevelChanged: (v) => setState(() => _levelFilter = v),
      onSearchChanged: (_) => setState(() {}),
      onAutoScrollToggled: () => setState(() => _autoScroll = !_autoScroll),
      onClearPinned: () {},
    );
  }
}

class _DiagnosisLogList extends StatefulWidget {
  @override
  State<_DiagnosisLogList> createState() => _DiagnosisLogListState();
}

class _DiagnosisLogListState extends State<_DiagnosisLogList> {
  String? _sourceFilter;
  String? _levelFilter;
  String _searchQuery = '';
  bool _autoScroll = true;
  int? _pinnedIndex;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<LogMessage> _filterLogs(List<LogMessage> logs) {
    return logs.where((log) {
      if (_levelFilter != null && _levelFilter != 'all') {
        if (!_meetsLevelFilter(log.level, _levelFilter!)) return false;
      }
      if (_sourceFilter != null && _sourceFilter != 'all') {
        if (!_matchesSource(log.target, _sourceFilter!)) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!log.message.toLowerCase().contains(q) &&
            !log.target.toLowerCase().contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  bool _meetsLevelFilter(String logLevel, String filter) {
    const order = ['trace', 'debug', 'info', 'warn', 'error'];
    final logIdx = order.indexOf(logLevel.toLowerCase());
    final filterIdx = order.indexOf(filter.toLowerCase());
    if (logIdx < 0 || filterIdx < 0) return logLevel.toLowerCase() == filter;
    return logIdx >= filterIdx;
  }

  bool _matchesSource(String target, String source) {
    final t = target.toLowerCase();
    switch (source) {
      case 'rust':
        return t != 'dart' && !t.startsWith('native-');
      case 'dart':
        return t == 'dart';
      case 'native-ios':
        return t.contains('ios') || t.contains('native_ios');
      case 'native-android':
        return t.contains('android') || t.contains('native_android');
      default:
        return true;
    }
  }

  Color _levelColor(String level) {
    switch (level.toUpperCase()) {
      case 'TRACE':
        return Colors.grey;
      case 'DEBUG':
        return Colors.blue;
      case 'INFO':
        return Colors.green;
      case 'WARN':
        return Colors.orange;
      case 'ERROR':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients && _autoScroll && _pinnedIndex == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LogMessage>(
      stream: LogService.instance.stream,
      builder: (context, snapshot) {
        final allLogs = LogService.instance.logs;
        final filtered = _filterLogs(allLogs);

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

        if (snapshot.hasData && _autoScroll && _pinnedIndex == null) {
          _scrollToBottom();
        }

        return ListView.builder(
          controller: _scrollController,
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final log = filtered[index];
            final isPinned = _pinnedIndex == index;
            return DiagnosisLogLine(
              log: log,
              levelColor: _levelColor(log.level),
              isPinned: isPinned,
              onTap: () => setState(() {
                _pinnedIndex = isPinned ? null : index;
              }),
            );
          },
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
