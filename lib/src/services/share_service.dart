import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';

/// Centralized sharing service for the Flutter app.
/// Wraps share_plus to provide a consistent interface for sharing content.
class ShareService {
  ShareService._();

  static final ShareService _instance = ShareService._();

  /// Singleton instance accessor.
  static ShareService get instance => _instance;

  /// Share plain text content with an optional subject.
  ///
  /// [text] is the content to share.
  /// [subject] is an optional subject line (used on some platforms like email).
  ///
  /// Returns a [ShareResult] indicating the outcome of the share action.
  Future<ShareResult> shareText(String text, {String? subject}) async {
    try {
      final result = await Share.share(
        text,
        subject: subject,
      );

      if (kDebugMode) {
        debugPrint('ShareService: Text shared with status ${result.status}');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShareService: Error sharing text: $e');
      }
      rethrow;
    }
  }

  /// Share a file with an optional text description.
  ///
  /// [path] is the absolute path to the file to share.
  /// [mimeType] is the MIME type of the file (e.g., 'text/csv', 'application/json').
  /// [text] is optional text to accompany the file.
  /// [subject] is an optional subject line.
  ///
  /// Returns a [ShareResult] indicating the outcome of the share action.
  Future<ShareResult> shareFile(
    String path,
    String mimeType, {
    String? text,
    String? subject,
  }) async {
    try {
      // Verify file exists
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('File does not exist: $path');
      }

      final xFile = XFile(path, mimeType: mimeType);
      final result = await Share.shareXFiles(
        [xFile],
        text: text,
        subject: subject,
      );

      if (kDebugMode) {
        debugPrint('ShareService: File shared with status ${result.status}');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShareService: Error sharing file: $e');
      }
      rethrow;
    }
  }

  /// Share multiple files with an optional text description.
  ///
  /// [paths] is a list of absolute paths to files to share.
  /// [mimeType] is the MIME type of the files (assumes all files have the same type).
  /// [text] is optional text to accompany the files.
  /// [subject] is an optional subject line.
  ///
  /// Returns a [ShareResult] indicating the outcome of the share action.
  Future<ShareResult> shareFiles(
    List<String> paths,
    String mimeType, {
    String? text,
    String? subject,
  }) async {
    try {
      // Verify all files exist
      for (final path in paths) {
        final file = File(path);
        if (!await file.exists()) {
          throw Exception('File does not exist: $path');
        }
      }

      final xFiles = paths.map((path) => XFile(path, mimeType: mimeType)).toList();
      final result = await Share.shareXFiles(
        xFiles,
        text: text,
        subject: subject,
      );

      if (kDebugMode) {
        debugPrint('ShareService: ${paths.length} files shared with status ${result.status}');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ShareService: Error sharing files: $e');
      }
      rethrow;
    }
  }
}
