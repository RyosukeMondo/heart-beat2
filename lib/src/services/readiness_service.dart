import 'dart:async';
import 'package:flutter/foundation.dart';
import '../bridge/api_generated.dart/api.dart';

/// Service for managing readiness data.
///
/// This service centralizes readiness score fetching and caching,
/// following the singleton pattern.
class ReadinessService {
  ReadinessService._();

  static final ReadinessService _instance = ReadinessService._();

  /// Singleton instance accessor.
  static ReadinessService get instance => _instance;

  /// Stream controller for readiness updates.
  final StreamController<ApiReadinessData> _readinessController =
      StreamController<ApiReadinessData>.broadcast();

  /// Cached readiness data.
  ApiReadinessData? _cachedReadiness;

  /// Get a broadcast stream of readiness updates.
  Stream<ApiReadinessData> get stream => _readinessController.stream;

  /// Get cached readiness data.
  ApiReadinessData? get cachedReadiness => _cachedReadiness;

  /// Load readiness score from the API.
  ///
  /// Results are cached and broadcast to [stream] listeners.
  Future<ApiReadinessData?> loadReadiness() async {
    try {
      final readiness = await getReadinessScore();
      _cachedReadiness = readiness;
      _readinessController.add(readiness);
      return readiness;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading readiness: $e');
      }
      rethrow;
    }
  }

  /// Dispose of resources.
  void dispose() {
    _readinessController.close();
  }
}
