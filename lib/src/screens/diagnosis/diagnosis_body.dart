import 'package:flutter/material.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'package:heart_beat/src/services/log_service.dart';
import 'connection_status_card.dart';
import 'filter_bar.dart';
import 'log_line.dart';
import 'operations_panel.dart';

class DiagnosisBody extends StatefulWidget {
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
  State<DiagnosisBody> createState() => _DiagnosisBodyState();
}

class _DiagnosisBodyState extends State<DiagnosisBody> {
  String? _sourceFilter;
  String? _levelFilter;
  String _searchQuery = '';
  bool _autoScroll = true;
  int? _pinnedIndex;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Stream<ApiConnectionStatus>? _connectionStatusStream;
  bool _mockActive = false;

  @override
  void initState() {
    super.initState();
    _connectionStatusStream = createConnectionStatusStream();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    return Column(
      children: [
        DiagnosisConnectionStatusCard(statusStream: _connectionStatusStream),
        const Divider(height: 1),
        DiagnosisFilterBar(
          sourceFilter: _sourceFilter,
          levelFilter: _levelFilter,
          searchController: _searchController,
          autoScroll: _autoScroll,
          onSourceChanged: (v) => setState(() => _sourceFilter = v),
          onLevelChanged: (v) => setState(() => _levelFilter = v),
          onSearchChanged: (v) => setState(() => _searchQuery = v),
          onAutoScrollToggled: () =>
              setState(() => _autoScroll = !_autoScroll),
          onClearPinned: () => setState(() => _pinnedIndex = null),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<LogMessage>(
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
          ),
        ),
        const Divider(height: 1),
        DiagnosisOperationsPanel(
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
        ),
      ],
    );
  }
}
