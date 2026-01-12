import 'package:flutter/material.dart';
import '../services/log_service.dart';
import '../bridge/api_generated.dart/api.dart';

/// Debug console widget that displays real-time logs with filtering capabilities.
/// Only available in debug builds.
class DebugConsole extends StatefulWidget {
  /// Callback invoked when the close button is pressed.
  final VoidCallback onClose;

  const DebugConsole({
    super.key,
    required this.onClose,
  });

  @override
  State<DebugConsole> createState() => _DebugConsoleState();
}

class _DebugConsoleState extends State<DebugConsole> {
  /// Current log level filter. null means show all levels.
  String? _levelFilter;

  /// Current search query for filtering logs by content.
  String _searchQuery = '';

  /// Controller for auto-scrolling to bottom.
  final ScrollController _scrollController = ScrollController();

  /// Text editing controller for search field.
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Filter logs based on current level and search query.
  List<LogMessage> _filterLogs(List<LogMessage> logs) {
    var filtered = logs;

    // Apply level filter
    if (_levelFilter != null) {
      filtered = filtered.where((log) => log.level == _levelFilter).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((log) {
        return log.message.toLowerCase().contains(query) ||
            log.target.toLowerCase().contains(query);
      }).toList();
    }

    // Limit to 200 most recent logs
    if (filtered.length > 200) {
      return filtered.sublist(filtered.length - 200);
    }

    return filtered;
  }

  /// Get color for log level badge.
  Color _getLevelColor(String level) {
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

  /// Scroll to bottom of log list.
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Header with filters and close button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bug_report, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Debug Console',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onClose,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Filter controls
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  // Level filter dropdown
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _levelFilter,
                      decoration: const InputDecoration(
                        labelText: 'Level',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All'),
                        ),
                        const DropdownMenuItem<String>(
                          value: 'TRACE',
                          child: Text('TRACE'),
                        ),
                        const DropdownMenuItem<String>(
                          value: 'DEBUG',
                          child: Text('DEBUG'),
                        ),
                        const DropdownMenuItem<String>(
                          value: 'INFO',
                          child: Text('INFO'),
                        ),
                        const DropdownMenuItem<String>(
                          value: 'WARN',
                          child: Text('WARN'),
                        ),
                        const DropdownMenuItem<String>(
                          value: 'ERROR',
                          child: Text('ERROR'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _levelFilter = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Search field
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                                padding: EdgeInsets.zero,
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Log list
            Expanded(
              child: StreamBuilder<LogMessage>(
                stream: LogService.instance.stream,
                builder: (context, snapshot) {
                  final allLogs = LogService.instance.logs;

                  if (allLogs.isEmpty) {
                    return Center(
                      child: Text(
                        'No logs available',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }

                  final filteredLogs = _filterLogs(allLogs);

                  if (filteredLogs.isEmpty) {
                    return Center(
                      child: Text(
                        'No logs match filters',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }

                  // Auto-scroll to bottom on new logs
                  if (snapshot.hasData && _searchQuery.isEmpty && _levelFilter == null) {
                    _scrollToBottom();
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      final timestamp = DateTime.fromMillisecondsSinceEpoch(
                        log.timestamp.toInt(),
                      );
                      final levelColor = _getLevelColor(log.level);

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                // Level badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: levelColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: levelColor,
                                      width: 1,
                                    ),
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
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Log message
                            Text(
                              log.message,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
