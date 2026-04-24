import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/domain/heart_rate.dart';
import 'package:heart_beat/src/services/log_service.dart';
import 'package:share_plus/share_plus.dart';

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

  Stream<ApiConnectionStatus>? _connectionStatusStream;

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
        // Connection status card
        _ConnectionStatusCard(statusStream: _connectionStatusStream),
        const Divider(height: 1),

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

        const Divider(height: 1),

        _OperationsPanel(
          onScan: _handleScan,
          onConnectLast: _handleConnectLast,
          onDisconnect: _handleDisconnect,
          onToggleMock: _handleToggleMock,
          onExport: _handleExport,
          onClearCache: _handleClearCache,
        ),
      ],
    );
  }

  Future<void> _handleScan() async {
    try {
      final devices = await scanDevices();
      if (!mounted) return;
      _showDevicePicker(devices);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    }
  }

  void _showDevicePicker(List<DiscoveredDevice> devices) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: devices.length,
        itemBuilder: (context, index) {
          final device = devices[index];
          return ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(device.name ?? 'Unknown'),
            subtitle: Text(device.id),
            onTap: () async {
              final sheetContext = context;
              Navigator.pop(sheetContext);
              try {
                await connectDevice(deviceId: device.id);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(sheetContext).showSnackBar(
                  SnackBar(content: Text('Connect failed: $e')),
                );
              }
            },
          );
        },
      ),
    );
  }

  Future<void> _handleConnectLast() async {
    try {
      await connectDevice(deviceId: 'last-connected');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connect last failed: $e')),
      );
    }
  }

  Future<void> _handleDisconnect() async {
    try {
      await disconnect();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Disconnect failed: $e')),
      );
    }
  }

  bool _mockActive = false;

  Future<void> _handleToggleMock() async {
    try {
      if (_mockActive) {
        await disconnect();
      } else {
        await startMockMode();
      }
      setState(() => _mockActive = !_mockActive);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mock mode failed: $e')),
      );
    }
  }

  Future<void> _handleExport() async {
    try {
      final sessions = await listSessions();
      if (sessions.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No sessions to export')),
        );
        return;
      }
      final lastSession = sessions.first;
      final id = await sessionPreviewId(preview: lastSession);
      final exported = await exportSession(id: id, format: ExportFormat.json);
      await Share.share(exported, subject: 'Heart Beat session export');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _handleClearCache() async {
    try {
      LogService.instance.clear();
      await seedDefaultPlans();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cache cleared')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Clear cache failed: $e')),
      );
    }
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

class _ConnectionStatusCard extends StatelessWidget {
  final Stream<ApiConnectionStatus>? statusStream;

  const _ConnectionStatusCard({this.statusStream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ApiConnectionStatus>(
      stream: statusStream ?? createConnectionStatusStream(),
      builder: (context, snapshot) {
        final status = snapshot.data;
        final theme = Theme.of(context);

        return FutureBuilder<_CardData?>(
          future: _getCardData(status),
          builder: (context, dataSnapshot) {
            final data = dataSnapshot.data ?? _defaultCardData(status);
            return Container(
              padding: const EdgeInsets.all(12),
              color: theme.colorScheme.surfaceContainerHighest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(data.icon, size: 20, color: data.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (data.isConnected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Connected',
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (data.isConnecting)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (data.deviceId.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.device_unknown,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            data.deviceId,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (data.error.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      data.error,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                      ),
                    ),
                  ],
                  if (data.isReconnecting) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: data.reconnectProgress,
                              backgroundColor: Colors.orange.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.orange.shade700,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${data.attempt}/${data.maxAttempts}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<_CardData?> _getCardData(ApiConnectionStatus? status) async {
    if (status == null) return null;
    final isConn = await connectionStatusIsConnected(status: status);
    final isConning = await connectionStatusIsConnecting(status: status);
    final isRecon = await connectionStatusIsReconnecting(status: status);
    final isFailed = await connectionStatusIsReconnectFailed(status: status);

    if (isConn) {
      final deviceId = await connectionStatusDeviceId(status: status) ?? '';
      return _CardData(
        label: 'Device Connected',
        icon: Icons.bluetooth_connected,
        color: Colors.green,
        isConnected: true,
        isConnecting: false,
        isReconnecting: false,
        deviceId: deviceId,
        error: '',
        attempt: 0,
        maxAttempts: 1,
      );
    }

    if (isConning) {
      return _CardData(
        label: 'Connecting...',
        icon: Icons.bluetooth_searching,
        color: Colors.blue,
        isConnected: false,
        isConnecting: true,
        isReconnecting: false,
        deviceId: '',
        error: '',
        attempt: 0,
        maxAttempts: 1,
      );
    }

    if (isRecon) {
      final attempt = await connectionStatusAttempt(status: status) ?? 0;
      final maxAttempts = await connectionStatusMaxAttempts(status: status) ?? 1;
      return _CardData(
        label: 'Reconnecting...',
        icon: Icons.sync,
        color: Colors.orange,
        isConnected: false,
        isConnecting: false,
        isReconnecting: true,
        deviceId: '',
        error: '',
        attempt: attempt,
        maxAttempts: maxAttempts,
      );
    }

    if (isFailed) {
      final reason = await connectionStatusFailureReason(status: status) ?? 'Unknown error';
      return _CardData(
        label: 'Connection Failed',
        icon: Icons.error_outline,
        color: Colors.red,
        isConnected: false,
        isConnecting: false,
        isReconnecting: false,
        deviceId: '',
        error: reason,
        attempt: 0,
        maxAttempts: 1,
      );
    }

    return _CardData(
      label: 'Disconnected',
      icon: Icons.bluetooth_disabled,
      color: Colors.grey,
      isConnected: false,
      isConnecting: false,
      isReconnecting: false,
      deviceId: '',
      error: '',
      attempt: 0,
      maxAttempts: 1,
    );
  }

  _CardData _defaultCardData(ApiConnectionStatus? status) {
    return _CardData(
      label: 'Unknown',
      icon: Icons.bluetooth_disabled,
      color: Colors.grey,
      isConnected: false,
      isConnecting: false,
      isReconnecting: false,
      deviceId: '',
      error: '',
      attempt: 0,
      maxAttempts: 1,
    );
  }
}

class _CardData {
  final String label;
  final IconData icon;
  final Color color;
  final bool isConnected;
  final bool isConnecting;
  final bool isReconnecting;
  final String deviceId;
  final String error;
  final int attempt;
  final int maxAttempts;

  _CardData({
    required this.label,
    required this.icon,
    required this.color,
    required this.isConnected,
    required this.isConnecting,
    required this.isReconnecting,
    required this.deviceId,
    required this.error,
    required this.attempt,
    required this.maxAttempts,
  });

  double get reconnectProgress =>
      maxAttempts > 0 ? attempt / maxAttempts : 0;
}

class _OperationsPanel extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onConnectLast;
  final VoidCallback onDisconnect;
  final VoidCallback onToggleMock;
  final VoidCallback onExport;
  final VoidCallback onClearCache;

  const _OperationsPanel({
    required this.onScan,
    required this.onConnectLast,
    required this.onDisconnect,
    required this.onToggleMock,
    required this.onExport,
    required this.onClearCache,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _OpButton(
            icon: Icons.bluetooth_searching,
            label: 'Scan',
            onPressed: onScan,
          ),
          _OpButton(
            icon: Icons.history,
            label: 'Connect Last',
            onPressed: onConnectLast,
          ),
          _OpButton(
            icon: Icons.bluetooth_disabled,
            label: 'Disconnect',
            onPressed: onDisconnect,
          ),
          _OpButton(
            icon: Icons.science,
            label: 'Mock',
            onPressed: onToggleMock,
          ),
          _OpButton(
            icon: Icons.ios_share,
            label: 'Export',
            onPressed: onExport,
          ),
          _OpButton(
            icon: Icons.delete_sweep,
            label: 'Clear Cache',
            onPressed: onClearCache,
          ),
        ],
      ),
    );
  }
}

class _OpButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _OpButton({
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