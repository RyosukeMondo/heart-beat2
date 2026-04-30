import 'package:flutter/material.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'log_service.dart';

/// Plain data type for UI-layer log display.
///
/// Decouples the UI from the FFI-generated LogMessage struct.
class LogEntry {
  final String level;
  final String target;
  final BigInt timestamp;
  final String message;

  const LogEntry({
    required this.level,
    required this.target,
    required this.timestamp,
    required this.message,
  });

  int get timestampMs => timestamp.toInt();

  static LogEntry fromLogMessage(LogMessage m) => LogEntry(
        level: m.level,
        target: m.target,
        timestamp: m.timestamp,
        message: m.message,
      );
}

/// Filter criteria for log messages.
class DiagnosisLogFilter {
  final String? sourceFilter;
  final String? levelFilter;
  final String searchQuery;

  const DiagnosisLogFilter({
    this.sourceFilter,
    this.levelFilter,
    this.searchQuery = '',
  });

  DiagnosisLogFilter copyWith({
    String? sourceFilter,
    String? levelFilter,
    String? searchQuery,
  }) {
    return DiagnosisLogFilter(
      sourceFilter: sourceFilter,
      levelFilter: levelFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Service for diagnosis log state — filter state, log stream access.
///
/// Encapsulates the filter state and LogService subscription from the UI,
/// exposing them through ChangeNotifier for reactive UI updates.
class DiagnosisLogService extends ChangeNotifier {
  DiagnosisLogService._();

  static final DiagnosisLogService _instance = DiagnosisLogService._();

  static DiagnosisLogService get instance => _instance;

  // ---------------------------------------------------------------------------
  // Filter state
  // ---------------------------------------------------------------------------

  String? _sourceFilter;
  String? _levelFilter;
  String _searchQuery = '';

  String? get sourceFilter => _sourceFilter;
  String? get levelFilter => _levelFilter;
  String get searchQuery => _searchQuery;

  void setSourceFilter(String? v) {
    _sourceFilter = v;
    notifyListeners();
  }

  void setLevelFilter(String? v) {
    _levelFilter = v;
    notifyListeners();
  }

  void setSearchQuery(String v) {
    _searchQuery = v;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Log stream — delegate to LogService
  // ---------------------------------------------------------------------------

  Stream<LogEntry> get stream =>
      LogService.instance.stream.map(LogEntry.fromLogMessage);

  List<LogEntry> get logs =>
      LogService.instance.logs.map(LogEntry.fromLogMessage).toList();

  // ---------------------------------------------------------------------------
  // Filtering
  // ---------------------------------------------------------------------------

  static const _levelOrder = ['trace', 'debug', 'info', 'warn', 'error'];

  static bool _meetsLevelFilter(String logLevel, String filter) {
    final logIdx = _levelOrder.indexOf(logLevel.toLowerCase());
    final filterIdx = _levelOrder.indexOf(filter.toLowerCase());
    if (logIdx < 0 || filterIdx < 0) return logLevel.toLowerCase() == filter;
    return logIdx >= filterIdx;
  }

  static bool _matchesSource(String target, String source) {
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

  List<LogEntry> filterLogs(List<LogEntry> logs) {
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

  Color levelColor(String level) {
    switch (level.toUpperCase()) {
      case 'TRACE':
        return const Color(0xFF9E9E9E);
      case 'DEBUG':
        return const Color(0xFF2196F3);
      case 'INFO':
        return const Color(0xFF4CAF50);
      case 'WARN':
        return const Color(0xFFFF9800);
      case 'ERROR':
        return const Color(0xFFF44336);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}