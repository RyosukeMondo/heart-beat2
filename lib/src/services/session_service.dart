import 'package:heart_beat/src/bridge/api_generated.dart/api.dart' as generated;

export 'package:heart_beat/src/bridge/api_generated.dart/api.dart'
    show ApiSessionSummaryPreview, ExportFormat;

/// Service for session data operations via the Rust API bridge.
///
/// Wraps the FRB-generated API to provide a stable, service-layer interface:
/// - [listSessions] for retrieving all session summaries
/// - [exportSession] for exporting a session in a given format
/// - [sessionPreviewId] for extracting the ID from a preview
class SessionService {
  SessionService._();

  static final SessionService _instance = SessionService._();

  static SessionService get instance => _instance;

  /// Returns all session summaries from the repository.
  Future<List<generated.ApiSessionSummaryPreview>> listSessions() {
    return generated.listSessions();
  }

  /// Exports a session with the given [id] in the specified [format].
  Future<String> exportSession({
    required String id,
    required generated.ExportFormat format,
  }) {
    return generated.exportSession(id: id, format: format);
  }

  /// Returns the session ID from a [preview].
  Future<String> sessionPreviewId({required generated.ApiSessionSummaryPreview preview}) {
    return generated.sessionPreviewId(preview: preview);
  }
}