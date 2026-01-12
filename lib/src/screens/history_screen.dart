import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../bridge/api_generated.dart/api.dart';

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

  Future<void> _deleteSession(ApiSessionSummaryPreview session) async {
    final sessionId = await sessionPreviewId(preview: session);

    // Show confirmation dialog
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text('Are you sure you want to delete this session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await deleteSession(id: sessionId);
      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session deleted'),
          duration: Duration(seconds: 2),
        ),
      );

      // Reload sessions
      _loadSessions();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete session: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session History'),
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
                              final status = data['status'] as String;

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
                                direction: DismissDirection.endToStart,
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
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          Theme.of(context).colorScheme.primaryContainer,
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
                                    trailing: const Icon(Icons.arrow_forward_ios),
                                    onTap: () => _openSessionDetail(session),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
    );
  }

  Future<Map<String, dynamic>> _loadSessionData(
      ApiSessionSummaryPreview session) async {
    final id = await sessionPreviewId(preview: session);
    final planName = await sessionPreviewPlanName(preview: session);
    final startTime = await sessionPreviewStartTime(preview: session);
    final durationSecs = await sessionPreviewDurationSecs(preview: session);
    final avgHr = await sessionPreviewAvgHr(preview: session);
    final status = await sessionPreviewStatus(preview: session);

    return {
      'id': id,
      'planName': planName,
      'startTime': startTime,
      'durationSecs': durationSecs,
      'avgHr': avgHr,
      'status': status,
    };
  }
}
