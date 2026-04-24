import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../bridge/api_generated.dart/api.dart';
import '../services/share_service.dart';
import '../widgets/session_detail_header.dart';
import '../widgets/session_detail_summary.dart';
import '../widgets/session_detail_hr_chart.dart';
import '../widgets/session_detail_time_in_zone.dart';
import '../widgets/session_export_menu.dart';

/// Detail screen showing comprehensive information about a completed training session
class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  // Session data
  String? _sessionId;
  String? _planName;
  int? _startTime;
  String? _status;
  int? _durationSecs;
  int? _avgHr;
  int? _maxHr;
  int? _minHr;
  List<int>? _timeInZone;
  List<(int, int)>? _hrSamples; // (timestamp_millis, bpm)

  bool _isLoading = true;
  String? _error;
  bool _isExporting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final sessionId = args['session_id'] as String;
    _sessionId = sessionId;
    _loadSession(sessionId);
  }

  Future<void> _loadSession(String sessionId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final session = await getSession(id: sessionId);
      if (!mounted) return;

      if (session == null) {
        setState(() {
          _error = 'Session not found';
          _isLoading = false;
        });
        return;
      }

      // Load all data from the session
      final planName = await sessionPlanName(session: session);
      final startTime = await sessionStartTime(session: session);
      final status = await sessionStatus(session: session);
      final durationSecs = await sessionSummaryDurationSecs(session: session);
      final avgHr = await sessionSummaryAvgHr(session: session);
      final maxHr = await sessionSummaryMaxHr(session: session);
      final minHr = await sessionSummaryMinHr(session: session);
      final timeInZone = await sessionSummaryTimeInZone(session: session);

      // Load HR samples
      final sampleCount = await sessionHrSamplesCount(session: session);
      final List<(int, int)> hrSamples = [];
      for (var i = BigInt.zero; i < sampleCount; i += BigInt.one) {
        final sample = await sessionHrSampleAt(session: session, index: i);
        if (sample != null) {
          hrSamples.add((sample.$1.toInt(), sample.$2));
        }
      }

      if (!mounted) return;

      setState(() {
        _planName = planName;
        _startTime = startTime.toInt();
        _status = status;
        _durationSecs = durationSecs;
        _avgHr = avgHr;
        _maxHr = maxHr;
        _minHr = minHr;
        _timeInZone = timeInZone;
        _hrSamples = hrSamples;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load session: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleExportAction(String action) async {
    if (_sessionId == null) {
      _showErrorSnackBar('Session ID not available');
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      switch (action) {
        case 'csv':
          final content = await exportSession(
            id: _sessionId!,
            format: ExportFormat.csv,
          );
          if (!mounted) return;
          await _shareFile(content, 'csv', 'text/csv');
          break;
        case 'json':
          final content = await exportSession(
            id: _sessionId!,
            format: ExportFormat.json,
          );
          if (!mounted) return;
          await _shareFile(content, 'json', 'application/json');
          break;
        case 'summary':
          final content = await exportSession(
            id: _sessionId!,
            format: ExportFormat.summary,
          );
          if (!mounted) return;
          await _shareText(content);
          break;
        case 'tcx':
          final content = await exportSessionTcx(sessionId: _sessionId!);
          if (!mounted) return;
          await _shareFile(content, 'tcx', 'application/xml');
          break;
        case 'gpx':
          final content = await exportSessionGpx(sessionId: _sessionId!);
          if (!mounted) return;
          await _shareFile(content, 'gpx', 'application/xml');
          break;
      }

      if (mounted) {
        _showSuccessSnackBar('Export completed successfully');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Export failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _shareFile(
    String content,
    String extension,
    String mimeType,
  ) async {
    try {
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'session_${_sessionId}_$timestamp.$extension';
      final filePath = '${tempDir.path}/$fileName';

      // Write content to file
      final file = File(filePath);
      await file.writeAsString(content);

      // Share the file
      await ShareService.instance.shareFile(
        filePath,
        mimeType,
        subject: 'Training Session Export',
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _shareText(String content) async {
    try {
      await ShareService.instance.shareText(
        content,
        subject: 'Training Session Summary',
      );
    } catch (e) {
      rethrow;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Details'),
        actions: [
          if (!_isLoading && _error == null && _planName != null)
            SessionExportMenu(
              sessionId: _sessionId!,
              isExporting: _isExporting,
              onExport: _handleExportAction,
            ),
        ],
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
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            )
          : _planName == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Session not found',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SessionDetailHeader(
                    planName: _planName!,
                    startTime: _startTime!,
                    status: _status!,
                  ),
                  SessionDetailSummary(
                    durationSecs: _durationSecs!,
                    avgHr: _avgHr!,
                    maxHr: _maxHr!,
                    minHr: _minHr!,
                  ),
                  SessionDetailHrChart(
                    hrSamples: _hrSamples!,
                    startTime: _startTime!,
                    minHr: _minHr!,
                    maxHr: _maxHr!,
                  ),
                  SessionDetailTimeInZone(
                    durationSecs: _durationSecs!,
                    timeInZone: _timeInZone!,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
