import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import '../bridge/api_generated.dart/api.dart';
import '../services/share_service.dart';

/// History screen displaying list of completed training sessions
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ApiSessionSummaryPreview> _sessions = [];
  bool _isLoading = false;
  String? _error;
  bool _selectionMode = false;
  final Set<String> _selectedSessionIds = {};

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sessions = await listSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load sessions: $e';
        _isLoading = false;
      });
    }
  }

void _openSessionDetail(ApiSessionSummaryPreview session) async {
    final sessionId = await sessionPreviewId(preview: session);
    if (!mounted) return;

    Navigator.pushNamed(
      context,
      '/session-detail',
      arguments: {'session_id': sessionId},
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedSessionIds.clear();
      }
    });
  }

  void _toggleSessionSelection(String sessionId) {
    setState(() {
      if (_selectedSessionIds.contains(sessionId)) {
        _selectedSessionIds.remove(sessionId);
        // Exit selection mode if no sessions are selected
        if (_selectedSessionIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedSessionIds.add(sessionId);
      }
    });
  }

  Future<void> _exportSelectedSessions() async {
    if (_selectedSessionIds.isEmpty) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Exporting sessions...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final zipPath = '${tempDir.path}/sessions_export_$timestamp.zip';

      // Create archive
      final archive = Archive();

      int exportCount = 0;
      for (final sessionId in _selectedSessionIds) {
        try {
          // Export session as JSON
          final jsonContent = await exportSession(
            id: sessionId,
            format: ExportFormat.json,
          );

          // Add to archive with a filename based on session ID
          final fileName = 'session_$sessionId.json';
          final bytes = jsonContent.codeUnits;
          archive.addFile(
            ArchiveFile(fileName, bytes.length, bytes),
          );

          exportCount++;
        } catch (e) {
          debugPrint('Failed to export session $sessionId: $e');
          // Continue with other sessions
        }
      }

      if (exportCount == 0) {
        throw Exception('Failed to export any sessions');
      }

      // Write ZIP file
      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) {
        throw Exception('Failed to create ZIP archive');
      }
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipData);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Share the ZIP file
      await ShareService.instance.shareFile(
        zipPath,
        'application/zip',
        subject: 'Training Sessions Export',
        text: 'Exported $exportCount training session(s)',
      );

      // Exit selection mode
      setState(() {
        _selectionMode = false;
        _selectedSessionIds.clear();
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported $exportCount session(s)'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export sessions: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectionMode
              ? '${_selectedSessionIds.length} selected'
              : 'Session History',
        ),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              )
            : null,
        actions: _selectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: () {
                    setState(() {
                      if (_selectedSessionIds.length == _sessions.length) {
                        // Deselect all
                        _selectedSessionIds.clear();
                      } else {
                        // Select all
                        for (final session in _sessions) {
                          sessionPreviewId(preview: session).then((id) {
                            if (mounted) {
                              setState(() {
                                _selectedSessionIds.add(id);
                              });
                            }
                          });
                        }
                      }
                    });
                  },
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadSessions,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No training sessions yet',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Complete a training session to see it here',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSessions,
                      child: ListView.builder(
                        itemCount: _sessions.length,
                        itemBuilder: (context, index) {
                          final session = _sessions[index];
                          return FutureBuilder<Map<String, dynamic>>(
                            future: _loadSessionData(session),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox.shrink();
                              }

                              final data = snapshot.data!;
                              final planName = data['planName'] as String;
                              final startTime = data['startTime'] as int;
                              final durationSecs = data['durationSecs'] as int;
                              final avgHr = data['avgHr'] as int;

                              final dateTime = DateTime.fromMillisecondsSinceEpoch(startTime);
                              final dateFormat = DateFormat('MMM d, y');
                              final timeFormat = DateFormat('HH:mm');

                              return Dismissible(
                                key: Key(data['id'] as String),
                                background: Container(
                                  color: Theme.of(context).colorScheme.error,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                direction: _selectionMode
                                    ? DismissDirection.none
                                    : DismissDirection.endToStart,
                                confirmDismiss: (direction) async {
                                  return await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Session'),
                                      content: const Text(
                                        'Are you sure you want to delete this session?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                Theme.of(context).colorScheme.error,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                onDismissed: (direction) async {
                                  try {
                                    await deleteSession(id: data['id'] as String);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Session deleted'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                      _loadSessions();
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to delete session: $e'),
                                          backgroundColor:
                                              Theme.of(context).colorScheme.error,
                                        ),
                                      );
                                      _loadSessions();
                                    }
                                  }
                                },
                                child: Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: ListTile(
                                    leading: _selectionMode
                                        ? Checkbox(
                                            value: _selectedSessionIds
                                                .contains(data['id'] as String),
                                            onChanged: (selected) {
                                              _toggleSessionSelection(
                                                  data['id'] as String);
                                            },
                                          )
                                        : CircleAvatar(
                                            backgroundColor: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer,
                                            child: Icon(
                                              Icons.favorite,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                          ),
                                    title: Text(
                                      planName,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(
                                          '${dateFormat.format(dateTime)} at ${timeFormat.format(dateTime)}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.timer_outlined,
                                              size: 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatDuration(durationSecs),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                            const SizedBox(width: 16),
                                            Icon(
                                              Icons.favorite_outline,
                                              size: 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$avgHr BPM',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    trailing: _selectionMode
                                        ? null
                                        : const Icon(Icons.arrow_forward_ios),
                                    onTap: _selectionMode
                                        ? () => _toggleSessionSelection(
                                            data['id'] as String)
                                        : () => _openSessionDetail(session),
                                    onLongPress: () {
                                      if (!_selectionMode) {
                                        setState(() {
                                          _selectionMode = true;
                                          _selectedSessionIds.add(data['id'] as String);
                                        });
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
      floatingActionButton: _selectionMode && _selectedSessionIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _exportSelectedSessions,
              icon: const Icon(Icons.file_download),
              label: const Text('Export All'),
            )
          : null,
    );
  }

  Future<Map<String, dynamic>> _loadSessionData(
      ApiSessionSummaryPreview session) async {
    final id = await sessionPreviewId(preview: session);
    final planName = await sessionPreviewPlanName(preview: session);
    final startTime = await sessionPreviewStartTime(preview: session);
    final durationSecs = await sessionPreviewDurationSecs(preview: session);
    final avgHr = await sessionPreviewAvgHr(preview: session);

    return {
      'id': id,
      'planName': planName,
      'startTime': startTime,
      'durationSecs': durationSecs,
      'avgHr': avgHr,
    };
  }
}
