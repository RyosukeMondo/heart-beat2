import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'session_service.dart';

/// Status of the local backup system.
///
/// Provides a snapshot of the current backup state including when the last
/// backup was created, how many sessions are stored, and the backup size.
class _SyncStatus {
  _SyncStatus({
    this.lastBackupTime,
    required this.sessionCount,
    required this.backupSizeBytes,
    required this.backupPath,
  });

  /// When the last backup was created (null if no backup exists).
  final DateTime? lastBackupTime;

  /// Number of sessions available for backup.
  final int sessionCount;

  /// Size of the most recent backup file in bytes (0 if none).
  final int backupSizeBytes;

  /// Path to the backup directory.
  final String backupPath;

  @override
  String toString() =>
      'SyncStatus(lastBackup: $lastBackupTime, sessions: $sessionCount, '
      'size: $backupSizeBytes bytes, path: $backupPath)';
}

/// Local backup and restore service for session data.
///
/// Provides the foundation for future cloud sync by managing local JSON
/// backups of all training sessions. Uses the existing Rust API bridge
/// ([listSessions], [getSession], [exportSession]) to export session data
/// and supports importing sessions from backup files.
///
/// Implemented as a singleton to ensure consistent backup state across the app.
class CloudSyncService {
  CloudSyncService._();

  static final CloudSyncService _instance = CloudSyncService._();

  /// Singleton instance accessor.
  static CloudSyncService get instance => _instance;

  /// Directory where backups are stored.
  Directory? _backupDir;

  /// Timestamp of the most recent backup.
  DateTime? _lastBackupTime;

  /// Whether the service has been initialized.
  bool _initialized = false;

  /// Name of the backup subdirectory within app documents.
  static const String _backupDirName = 'heart_beat_backups';

  /// File name for the latest full backup.
  static const String _latestBackupName = 'sessions_backup.json';

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initialize the backup directory structure.
  ///
  /// Creates the backup directory inside the app's documents folder if it does
  /// not already exist. Must be called before any other methods.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      _backupDir = Directory('${documentsDir.path}/$_backupDirName');

      if (!_backupDir!.existsSync()) {
        await _backupDir!.create(recursive: true);
      }

      // Check for an existing backup to recover lastBackupTime.
      final latestBackup = File('${_backupDir!.path}/$_latestBackupName');
      if (latestBackup.existsSync()) {
        _lastBackupTime = latestBackup.lastModifiedSync();
      }

      _initialized = true;

      if (kDebugMode) {
        debugPrint('CloudSyncService initialized at ${_backupDir!.path}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing CloudSyncService: $e');
      }
      rethrow;
    }
  }

  /// Throws [StateError] if the service has not been initialized.
  void _ensureInitialized() {
    if (!_initialized || _backupDir == null) {
      throw StateError(
        'CloudSyncService has not been initialized. '
        'Call initialize() first.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Export all sessions to a single JSON backup file.
  ///
  /// Iterates over every session returned by [listSessions], exports each one
  /// via [exportSession] with [ExportFormat.json], and writes the combined
  /// payload to disk.
  ///
  /// Returns the absolute path to the created backup file.
  Future<String> exportAllSessions() async {
    _ensureInitialized();

    try {
      final sessions = await SessionService.instance.listSessions();
      final exportedSessions = <Map<String, dynamic>>[];

      for (final preview in sessions) {
        final id = await SessionService.instance.sessionPreviewId(preview: preview);

        try {
          final jsonString = await SessionService.instance.exportSession(
            id: id,
            format: ExportFormat.json,
          );
          final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
          exportedSessions.add(decoded);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Warning: failed to export session $id: $e');
          }
          // Continue with remaining sessions rather than aborting.
        }
      }

      final backup = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'sessionCount': exportedSessions.length,
        'sessions': exportedSessions,
      };

      final backupFile = File('${_backupDir!.path}/$_latestBackupName');
      final encoder = const JsonEncoder.withIndent('  ');
      await backupFile.writeAsString(encoder.convert(backup));

      _lastBackupTime = DateTime.now();

      if (kDebugMode) {
        debugPrint(
          'CloudSyncService: exported ${exportedSessions.length} sessions '
          'to ${backupFile.path}',
        );
      }

      return backupFile.path;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error exporting sessions: $e');
      }
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// Import sessions from a JSON backup file.
  ///
  /// Reads the backup file at [filePath], validates its structure, and returns
  /// the number of sessions found in the file. The parsed sessions are
  /// available for future processing (e.g., merging into the local store once
  /// a write API is available).
  ///
  /// Throws [FormatException] if the file is not a valid backup.
  Future<int> importSessions(String filePath) async {
    _ensureInitialized();

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw FileSystemException('Backup file not found', filePath);
      }

      final content = await file.readAsString();
      final decoded = jsonDecode(content);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Backup file has invalid root structure');
      }

      final version = decoded['version'];
      if (version == null) {
        throw const FormatException('Backup file missing version field');
      }

      final sessions = decoded['sessions'];
      if (sessions is! List) {
        throw const FormatException('Backup file missing sessions array');
      }

      final importCount = sessions.length;

      if (kDebugMode) {
        debugPrint(
          'CloudSyncService: read $importCount sessions from $filePath',
        );
      }

      return importCount;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error importing sessions: $e');
      }
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------

  /// Get the current sync/backup status.
  ///
  /// Returns a [SyncStatus] snapshot with the last backup time, number of
  /// sessions currently in the repository, backup file size, and backup path.
  Future<_SyncStatus> getSyncStatus() async {
    _ensureInitialized();

    try {
      final sessions = await SessionService.instance.listSessions();

      var backupSizeBytes = 0;
      final latestBackup = File('${_backupDir!.path}/$_latestBackupName');
      if (latestBackup.existsSync()) {
        backupSizeBytes = latestBackup.lengthSync();
      }

      return _SyncStatus(
        lastBackupTime: _lastBackupTime,
        sessionCount: sessions.length,
        backupSizeBytes: backupSizeBytes,
        backupPath: _backupDir!.path,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting sync status: $e');
      }
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Automatic backup
  // ---------------------------------------------------------------------------

  /// Create an automatic backup of all sessions.
  ///
  /// Convenience wrapper around [exportAllSessions] intended for use in
  /// lifecycle hooks (e.g., on app pause or periodic timers).
  Future<void> createBackup() async {
    _ensureInitialized();

    try {
      final path = await exportAllSessions();
      if (kDebugMode) {
        debugPrint('CloudSyncService: automatic backup created at $path');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error creating automatic backup: $e');
      }
      rethrow;
    }
  }

  /// Export the most recent session for sharing.
  ///
  /// Returns the exported session data as a JSON string that can be shared.
  /// Throws if no sessions exist.
  Future<String> exportLastSession() async {
    final sessions = await SessionService.instance.listSessions();
    if (sessions.isEmpty) {
      throw Exception('No sessions to export');
    }
    final lastSession = sessions.first;
    final id = await SessionService.instance.sessionPreviewId(preview: lastSession);
    return SessionService.instance.exportSession(id: id, format: ExportFormat.json);
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Release resources held by the service.
  ///
  /// As a singleton this is typically only called on app termination.
  Future<void> dispose() async {
    _initialized = false;
    _backupDir = null;
    _lastBackupTime = null;

    if (kDebugMode) {
      debugPrint('CloudSyncService disposed');
    }
  }
}
