import 'dart:async';
import 'dart:collection';
import 'dart:io' show Directory, File, FileMode;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
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

  /// Retention period in days.
  static const int _retentionDays = 7;

  /// Log directory name.
  static const String _logDirName = 'logs';

  /// Internal log buffer with FIFO eviction.
  final Queue<LogMessage> _logBuffer = Queue<LogMessage>();

  /// Broadcast controller for distributing logs to listeners.
  final StreamController<LogMessage> _controller =
      StreamController<LogMessage>.broadcast();

  /// Subscription to the Rust log stream.
  StreamSubscription<LogMessage>? _rustSubscription;

  /// Original FlutterError.onError handler.
  FlutterExceptionHandler? _originalOnError;

  /// Original PlatformDispatcher.onError handler.
  /// Type: bool Function(Object error, StackTrace? stackTrace)?
  dynamic _originalPlatformOnError;

  /// Rolling file writer for Dart logs.
  _DartLogWriter? _dartLogWriter;

  /// Whether the service has been initialized.
  bool _initialized = false;

  /// Initialize the log service.
  ///
  /// Must be called once during app startup, after WidgetsFlutterBinding.ensureInitialized().
  /// Sets up:
  /// - Rolling file writer for Dart logs
  /// - debugPrint hook that routes through this service
  /// - FlutterError.onError hook for uncaught exceptions
  /// - PlatformDispatcher.instance.onError hook for platform errors
  /// - 7-day retention sweep on startup
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final logDir = await _getLogDirectory();
      _dartLogWriter = _DartLogWriter(logDir.path);
      await _dartLogWriter!.sweepOldFiles();

      _installDebugPrintHook();
      _installErrorHooks();
    } catch (e) {
      debugPrint('LogService initialization failed: $e');
    }
  }

  Future<Directory> _getLogDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final logDir = Directory('${appDir.path}/$_logDirName');
    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }
    return logDir;
  }

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
      debugPrint(
        '[${timestamp.toIso8601String()}] ${log.level} ${log.target}: ${log.message}',
      );
    }

    // Broadcast to listeners
    _controller.add(log);
  }

  /// Install the debugPrint hook that routes through this service.
  void _installDebugPrintHook() {
    debugPrint = (String? message, {int? wrapWidth}) {
      _log('DEBUG', 'dart', message ?? '');
    };
  }

  /// Install FlutterError.onError and PlatformDispatcher.onError hooks.
  void _installErrorHooks() {
    _originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _logException(details);
      _originalOnError?.call(details);
    };

    _originalPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace? stack) {
      final msg = 'PlatformDispatcher.onError: $error\n$stack';
      _log('ERROR', 'dart', msg);
      final original = _originalPlatformOnError;
      if (original != null) {
        return original(error, stack);
      }
      return false;
    };
  }

  void _log(String level, String target, String message) {
    final now = DateTime.now();
    final timestamp = BigInt.from(now.millisecondsSinceEpoch);

    final logMsg = LogMessage(
      level: level,
      target: target,
      timestamp: timestamp,
      message: message,
    );

    // Add to buffer
    _logBuffer.add(logMsg);
    if (_logBuffer.length > _maxLogEntries) {
      _logBuffer.removeFirst();
    }

    // Write to rolling file
    _dartLogWriter?.append(now, level, target, message);

    // Broadcast to listeners
    _controller.add(logMsg);
  }

  void _logException(FlutterErrorDetails details) {
    final message =
        '${details.exceptionAsString()}\n${details.stack?.toString() ?? 'no stack'}';
    _log('ERROR', 'dart', message);
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

  /// Flush pending writes to disk.
  Future<void> flush() async {
    await _dartLogWriter?.flush();
  }

  /// Dispose of resources.
  /// Should be called when the service is no longer needed.
  void dispose() {
    _rustSubscription?.cancel();
    _controller.close();
    _dartLogWriter?.close();
  }
}

/// Rolling file writer for Dart log entries.
/// Uses a separate file per day with append mode for crash-safety.
class _DartLogWriter {
  _DartLogWriter(this._logDirPath);

  final String _logDirPath;

  static const String _prefix = 'heart-beat-dart';

  String _filenameFor(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Append a log line to today's file.
  /// Uses FileMode.append so concurrent writes and crashes are safe.
  void append(DateTime now, String level, String target, String message) {
    final dateStr = _filenameFor(now);
    final path = '$_logDirPath/$_prefix.$dateStr.log';
    final line = '${now.toIso8601String()} $level $target: $message\n';

    try {
      final file = File(path);
      file.writeAsStringSync(line, mode: FileMode.append);
    } catch (_) {
      // Best-effort — never throw from log writer
    }
  }

  /// Flush is a no-op since writeAsStringSync is synchronous.
  Future<void> flush() async {}

  /// Close is a no-op for writeAsStringSync approach.
  Future<void> close() async {}

  /// Delete log files older than [LogService._retentionDays] days.
  Future<void> sweepOldFiles() async {
    try {
      final dir = Directory(_logDirPath);
      if (!await dir.exists()) return;

      final cutoff = DateTime.now().subtract(const Duration(days: LogService._retentionDays));
      await for (final entity in dir.list()) {
        if (entity is File) {
          final name = entity.path.split('/').last;
          if (!name.startsWith(_prefix) || !name.endsWith('.log')) continue;
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete();
          }
        }
      }
    } catch (_) {
      // Best-effort cleanup
    }
  }
}