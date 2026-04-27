import 'package:flutter/material.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'log_service.dart';

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
  // UI state
  // ---------------------------------------------------------------------------

  bool _autoScroll = true;
  int? _pinnedIndex;
  final ScrollController _scrollController = ScrollController();

  bool get autoScroll => _autoScroll;
  int? get pinnedIndex => _pinnedIndex;
  ScrollController get scrollController => _scrollController;

  void toggleAutoScroll() {
    _autoScroll = !_autoScroll;
    notifyListeners();
  }

  void togglePinned(int index) {
    _pinnedIndex = (_pinnedIndex == index) ? null : index;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Log stream — delegate to LogService
  // ---------------------------------------------------------------------------

  Stream<LogMessage> get stream => LogService.instance.stream;

  List<LogMessage> get logs => LogService.instance.logs;

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

  List<LogMessage> filterLogs(List<LogMessage> logs) {
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