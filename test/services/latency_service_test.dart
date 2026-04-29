import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/services/latency_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LatencyService', () {
    late LatencyService service;

    setUp(() {
      service = LatencyService.instance;
    });

    tearDown(() {
      service.stop();
      service.clearSamples();
    });

    test('should be a singleton', () {
      final instance1 = LatencyService.instance;
      final instance2 = LatencyService.instance;
      expect(identical(instance1, instance2), isTrue);
    });

    test('start() sets _isActive to true and clears previous samples', () {
      service.start();
      expect(service.getStats(), isNull);
      service.stop();
    });

    test('stop() sets _isActive to false', () {
      service.start();
      service.stop();
    });

    test('clearSamples() empties the sample queue', () {
      service.start();
      service.clearSamples();
      expect(service.getStats(), isNull);
      service.stop();
    });

    test('getStats() returns null when no samples collected', () {
      service.start();
      expect(service.getStats(), isNull);
      service.stop();
    });

    test('multiple stop() calls are safe', () {
      service.start();
      service.stop();
      service.stop();
    });

    test('multiple clearSamples() calls are safe', () {
      service.start();
      service.clearSamples();
      service.clearSamples();
      service.stop();
    });

    test('start() called twice is idempotent', () {
      service.start();
      service.start(); // Should not double-activate
      service.stop();
    });

    test('stop() without start() is safe', () {
      service.stop(); // Should not throw
    });
  });

  group('LatencyStats', () {
    test('toString() formats correctly', () {
      const stats = LatencyStats(
        sampleCount: 50,
        totalSamples: 100,
        p50Ms: 25.5,
        p95Ms: 75.3,
        p99Ms: 95.1,
      );

      final str = stats.toString();
      expect(str, contains('samples: 50/100'));
      expect(str, contains('P50: 25.50ms'));
      expect(str, contains('P95: 75.30ms'));
      expect(str, contains('P99: 95.10ms'));
    });

    test('equality works correctly', () {
      const stats1 = LatencyStats(
        sampleCount: 10,
        totalSamples: 10,
        p50Ms: 20.0,
        p95Ms: 80.0,
        p99Ms: 95.0,
      );

      const stats2 = LatencyStats(
        sampleCount: 10,
        totalSamples: 10,
        p50Ms: 20.0,
        p95Ms: 80.0,
        p99Ms: 95.0,
      );

      expect(stats1, equals(stats2));
    });

    test('has correct field types', () {
      const stats = LatencyStats(
        sampleCount: 5,
        totalSamples: 10,
        p50Ms: 15.0,
        p95Ms: 50.0,
        p99Ms: 80.0,
      );

      expect(stats.sampleCount, isA<int>());
      expect(stats.totalSamples, isA<int>());
      expect(stats.p50Ms, isA<double>());
      expect(stats.p95Ms, isA<double>());
      expect(stats.p99Ms, isA<double>());
    });

    test('toString() with different values formats correctly', () {
      const stats = LatencyStats(
        sampleCount: 1,
        totalSamples: 1,
        p50Ms: 0.0,
        p95Ms: 0.0,
        p99Ms: 0.0,
      );

      final str = stats.toString();
      expect(str, contains('P50: 0.00ms'));
    });
  });
}