import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../bridge/api_generated.dart/api.dart';

/// Service for tracking and logging end-to-end latency from BLE event to UI update.
///
/// Collects latency samples and periodically logs percentile statistics (P50, P95, P99).
/// Used to validate the P95 < 100ms requirement from BLE notification to UI rendering.
class LatencyService {
  LatencyService._();

  static final LatencyService _instance = LatencyService._();

  /// Singleton instance accessor.
  static LatencyService get instance => _instance;

  /// Maximum number of latency samples to keep in the sliding window.
  static const int _maxSamples = 1000;

  /// How often to log percentile statistics (in seconds).
  static const int _logIntervalSecs = 30;

  /// Sliding window of latency samples in microseconds.
  final Queue<int> _latencySamples = Queue<int>();

  /// Timer for periodic logging.
  Timer? _logTimer;

  /// Total number of samples recorded (for debugging).
  int _totalSamples = 0;

  /// Whether the service is currently active.
  bool _isActive = false;

  /// Start collecting latency samples and periodic logging.
  void start() {
    if (_isActive) return;

    _isActive = true;
    _latencySamples.clear();
    _totalSamples = 0;

    // Start periodic logging
    _logTimer = Timer.periodic(
      const Duration(seconds: _logIntervalSecs),
      (_) => _logPercentiles(),
    );

    if (kDebugMode) {
      debugPrint('[LatencyService] Started latency tracking');
    }
  }

  /// Stop collecting latency samples and cancel periodic logging.
  void stop() {
    if (!_isActive) return;

    _isActive = false;
    _logTimer?.cancel();
    _logTimer = null;

    // Log final statistics before stopping
    if (_latencySamples.isNotEmpty) {
      _logPercentiles();
    }

    if (kDebugMode) {
      debugPrint('[LatencyService] Stopped latency tracking');
    }
  }

  /// Record a latency sample when HR data is received in the UI.
  ///
  /// Calculates latency from BLE receive timestamp to current time.
  /// This should be called immediately when HR data arrives in the UI layer.
  Future<void> recordSample(ApiFilteredHeartRate hrData) async {
    if (!_isActive) return;

    try {
      // Get the receive timestamp from Rust (microseconds)
      final receiveTimestampMicros = await hrReceiveTimestampMicros(data: hrData);

      if (receiveTimestampMicros == null) {
        // Timestamp not available, skip this sample
        return;
      }

      // Get current time in microseconds
      final nowMicros = DateTime.now().microsecondsSinceEpoch;

      // Calculate latency in microseconds
      final latencyMicros = nowMicros - receiveTimestampMicros.toInt();

      // Only record positive latencies (sanity check)
      if (latencyMicros > 0 && latencyMicros < 10000000) { // < 10 seconds
        _recordLatency(latencyMicros);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LatencyService] Error recording sample: $e');
      }
    }
  }

  /// Internal method to add a latency sample to the sliding window.
  void _recordLatency(int latencyMicros) {
    _latencySamples.add(latencyMicros);
    _totalSamples++;

    // Maintain sliding window size
    if (_latencySamples.length > _maxSamples) {
      _latencySamples.removeFirst();
    }
  }

  /// Calculate and log percentile statistics.
  void _logPercentiles() {
    if (_latencySamples.isEmpty) {
      if (kDebugMode) {
        debugPrint('[LatencyService] No samples collected yet');
      }
      return;
    }

    // Copy and sort samples for percentile calculation
    final sorted = List<int>.from(_latencySamples)..sort();
    final count = sorted.length;

    // Calculate percentiles
    final p50Micros = _percentile(sorted, 50);
    final p95Micros = _percentile(sorted, 95);
    final p99Micros = _percentile(sorted, 99);

    // Convert to milliseconds for logging
    final p50Ms = p50Micros / 1000.0;
    final p95Ms = p95Micros / 1000.0;
    final p99Ms = p99Micros / 1000.0;

    // Log statistics
    debugPrint('[LatencyService] Latency Statistics:');
    debugPrint('  Samples: $count (Total: $_totalSamples)');
    debugPrint('  P50: ${p50Ms.toStringAsFixed(2)} ms');
    debugPrint('  P95: ${p95Ms.toStringAsFixed(2)} ms');
    debugPrint('  P99: ${p99Ms.toStringAsFixed(2)} ms');

    // Warn if P95 exceeds target
    if (p95Ms > 100.0) {
      debugPrint('  ⚠️  WARNING: P95 latency exceeds 100ms target!');
    } else {
      debugPrint('  ✓ P95 latency meets <100ms requirement');
    }
  }

  /// Calculate the percentile value from a sorted list.
  ///
  /// Uses the nearest-rank method.
  int _percentile(List<int> sorted, int percentile) {
    if (sorted.isEmpty) return 0;
    if (sorted.length == 1) return sorted[0];

    final rank = (percentile / 100.0) * sorted.length;
    final index = rank.ceil() - 1;
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  /// Get current latency statistics (for debugging/UI display).
  LatencyStats? getStats() {
    if (_latencySamples.isEmpty) return null;

    final sorted = List<int>.from(_latencySamples)..sort();
    final p50 = _percentile(sorted, 50) / 1000.0;
    final p95 = _percentile(sorted, 95) / 1000.0;
    final p99 = _percentile(sorted, 99) / 1000.0;

    return LatencyStats(
      sampleCount: sorted.length,
      totalSamples: _totalSamples,
      p50Ms: p50,
      p95Ms: p95,
      p99Ms: p99,
    );
  }

  /// Clear all collected samples.
  void clearSamples() {
    _latencySamples.clear();
    _totalSamples = 0;
    if (kDebugMode) {
      debugPrint('[LatencyService] Cleared all samples');
    }
  }
}

/// Latency statistics snapshot.
class LatencyStats {
  final int sampleCount;
  final int totalSamples;
  final double p50Ms;
  final double p95Ms;
  final double p99Ms;

  const LatencyStats({
    required this.sampleCount,
    required this.totalSamples,
    required this.p50Ms,
    required this.p95Ms,
    required this.p99Ms,
  });

  @override
  String toString() {
    return 'LatencyStats(samples: $sampleCount/$totalSamples, '
        'P50: ${p50Ms.toStringAsFixed(2)}ms, '
        'P95: ${p95Ms.toStringAsFixed(2)}ms, '
        'P99: ${p99Ms.toStringAsFixed(2)}ms)';
  }
}
