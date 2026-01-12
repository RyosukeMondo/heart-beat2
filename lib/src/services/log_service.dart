import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../bridge/api_generated.dart/api.dart';

/// Centralized log management service for the Flutter app.
/// Manages log collection, storage, and distribution to listeners.
class LogService {
  LogService._();

  static final LogService _instance = LogService._();

  /// Singleton instance accessor.
  static LogService get instance => _instance;

  /// Maximum number of log entries to keep in memory.
  static const int _maxLogEntries = 1000;

  /// Internal log buffer with FIFO eviction.
  final Queue<LogMessage> _logBuffer = Queue<LogMessage>();

  /// Broadcast controller for distributing logs to listeners.
  final StreamController<LogMessage> _controller = StreamController<LogMessage>.broadcast();

  /// Subscription to the Rust log stream.
  StreamSubscription<LogMessage>? _rustSubscription;

  /// Subscribe to the Rust log stream.
  /// Should be called once during app initialization with the stream from initLogging().
  void subscribe(Stream<LogMessage> rustLogStream) {
    _rustSubscription?.cancel();
    _rustSubscription = rustLogStream.listen(
      _handleLogMessage,
      onError: (error) {
        if (kDebugMode) {
          debugPrint('LogService error: $error');
        }
      },
    );
  }

  /// Handle incoming log messages from Rust.
  void _handleLogMessage(LogMessage log) {
    // Add to buffer with size limit
    _logBuffer.add(log);
    if (_logBuffer.length > _maxLogEntries) {
      _logBuffer.removeFirst();
    }

    // Print to debug console in debug mode
    if (kDebugMode) {
      final timestamp = DateTime.fromMillisecondsSinceEpoch(log.timestamp.toInt());
      debugPrint('[${timestamp.toIso8601String()}] ${log.level} ${log.target}: ${log.message}');
    }

    // Broadcast to listeners
    _controller.add(log);
  }

  /// Get a broadcast stream of log messages.
  /// New listeners will not receive historical logs.
  Stream<LogMessage> get stream => _controller.stream;

  /// Get all stored logs as an unmodifiable list.
  List<LogMessage> get logs => UnmodifiableListView(_logBuffer);

  /// Clear all stored logs.
  /// Does not affect active stream listeners.
  void clear() {
    _logBuffer.clear();
  }

  /// Dispose of resources.
  /// Should be called when the service is no longer needed.
  void dispose() {
    _rustSubscription?.cancel();
    _controller.close();
  }
}
