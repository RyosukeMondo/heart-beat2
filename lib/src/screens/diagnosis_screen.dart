import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'package:heart_beat/src/services/log_service.dart';

/// Diagnosis screen — a debug/dev surface showing live device state,
/// log viewer, and operations panel.
/// Gated on kDebugMode; production users cannot stumble into it.
class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({super.key});

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('diagnosisScreen'),
      appBar: AppBar(
        title: const Text('Diagnosis'),
      ),
      body: const _DiagnosisBody(),
    );
  }
}

class _DiagnosisBody extends StatefulWidget {
  const _DiagnosisBody();

  @override
  State<_DiagnosisBody> createState() => _DiagnosisBodyState();
}

class _DiagnosisBodyState extends State<_DiagnosisBody> {
  String? _sourceFilter;
  String? _levelFilter;
  String _searchQuery = '';
  bool _autoScroll = true;
  int? _pinnedIndex;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
        // Filter bar
        _FilterBar(
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

        // Log list
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
                  return _LogLine(
                    log: log,
                    levelColor: _levelColor(log.level),
                    isPinned: isPinned,
                    onTap: () => setState(() {
                      _pinnedIndex = isPinned ? null : index;
                    }),
                    onLongPress: () {
                      Clipboard.setData(
                          ClipboardData(text: '${log.target}: ${log.message}'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Log line copied to clipboard'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String? sourceFilter;
  final String? levelFilter;
  final TextEditingController searchController;
  final bool autoScroll;
  final ValueChanged<String?> onSourceChanged;
  final ValueChanged<String?> onLevelChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAutoScrollToggled;
  final VoidCallback onClearPinned;

  const _FilterBar({
    required this.sourceFilter,
    required this.levelFilter,
    required this.searchController,
    required this.autoScroll,
    required this.onSourceChanged,
    required this.onLevelChanged,
    required this.onSearchChanged,
    required this.onAutoScrollToggled,
    required this.onClearPinned,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Source filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Source: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                ...['all', 'rust', 'dart'].map((s) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: FilterChip(
                        label: Text(s.toUpperCase()),
                        selected: (sourceFilter ?? 'all') == s,
                        onSelected: (_) => onSourceChanged(s == 'all' ? null : s),
                        visualDensity: VisualDensity.compact,
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Level + Search row
          Row(
            children: [
              // Level dropdown
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: levelFilter ?? 'all',
                  decoration: const InputDecoration(
                    labelText: 'Level',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'trace', child: Text('TRACE')),
                    DropdownMenuItem(value: 'debug', child: Text('DEBUG')),
                    DropdownMenuItem(value: 'info', child: Text('INFO')),
                    DropdownMenuItem(value: 'warn', child: Text('WARN')),
                    DropdownMenuItem(value: 'error', child: Text('ERROR')),
                  ],
                  onChanged: (v) => onLevelChanged(v == 'all' ? null : v),
                ),
              ),
              const SizedBox(width: 8),

              // Search field
              Expanded(
                flex: 2,
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    labelText: 'Search',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                            padding: EdgeInsets.zero,
                          )
                        : null,
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              const SizedBox(width: 8),

              // Auto-scroll toggle
              IconButton(
                icon: Icon(
                  autoScroll ? Icons.vertical_align_bottom : Icons.push_pin,
                  color: autoScroll ? Colors.green : Colors.orange,
                ),
                tooltip: autoScroll ? 'Auto-scroll ON' : 'Auto-scroll OFF (pinned)',
                onPressed: onAutoScrollToggled,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  final LogMessage log;
  final Color levelColor;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _LogLine({
    required this.log,
    required this.levelColor,
    required this.isPinned,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      log.timestamp.toInt(),
    );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPinned
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 0.5,
            ),
            left: isPinned
                ? BorderSide(color: theme.colorScheme.primary, width: 3)
                : BorderSide.none,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Level badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: levelColor, width: 1),
                  ),
                  child: Text(
                    log.level,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: levelColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Timestamp
                Text(
                  '${timestamp.hour.toString().padLeft(2, '0')}:'
                  '${timestamp.minute.toString().padLeft(2, '0')}:'
                  '${timestamp.second.toString().padLeft(2, '0')}.'
                  '${(timestamp.millisecond ~/ 10).toString().padLeft(2, '0')}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),

                // Target
                Expanded(
                  child: Text(
                    log.target,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                if (isPinned)
                  Icon(
                    Icons.push_pin,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
            const SizedBox(height: 4),

            // Message
            Text(
              log.message,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}