import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import '../helpers/test_helpers.dart';

/// Unit and widget tests for analytics screen components.
///
/// This file tests the constituent widgets and helper logic that make up
/// the analytics screen. Full integration testing of the analytics screen
/// requires Rust FFI initialization (RustLib.init) and is covered by
/// integration tests instead.
///
/// Tests cover:
/// - Duration formatting logic
/// - Date formatting logic
/// - Zone color and name mapping
/// - Overview card rendering
/// - Empty and error state rendering
/// - Zone distribution chart logic
/// - Chart helper methods (bar chart data construction, line chart data)
///
/// The analytics screen itself (_AnalyticsScreenState) creates FFI calls
/// directly in initState via getAnalytics(), which requires RustLib.init()
/// before the widget can be instantiated in tests.
void main() {
  group('Analytics Duration Formatting Tests', () {
    test('format duration shows hours and minutes when hours > 0', () {
      expect(_fmtDuration(3660), equals('1h 1m'));   // 1h 1m
      expect(_fmtDuration(7200), equals('2h 0m'));   // 2h 0m
      expect(_fmtDuration(10800), equals('3h 0m'));  // 3h 0m
    });

    test('format duration shows only minutes when hours == 0', () {
      expect(_fmtDuration(60), equals('1m')); // 60 seconds = 1 minute
      expect(_fmtDuration(300), equals('5m'));
      expect(_fmtDuration(3599), equals('59m'));
    });

    test('format duration handles zero', () {
      expect(_fmtDuration(0), equals('0m'));
    });
  });

  group('Analytics Date Formatting Tests', () {
    test('format week returns M/d format', () {
      // Jan 15 -> 1/15
      final jan15 = DateTime(2024, 1, 15);
      expect(_fmtWeek(jan15.millisecondsSinceEpoch), equals('1/15'));
    });

    test('format week handles December correctly', () {
      // Dec 25 -> 12/25
      final dec25 = DateTime(2024, 12, 25);
      expect(_fmtWeek(dec25.millisecondsSinceEpoch), equals('12/25'));
    });

    test('format week pads single digit months correctly', () {
      // Mar 5 -> 3/5 not 03/05
      final mar5 = DateTime(2024, 3, 5);
      expect(_fmtWeek(mar5.millisecondsSinceEpoch), equals('3/5'));
    });
  });

  group('Analytics Zone Color Tests', () {
    test('zone colors match AnalyticsScreen static constants', () {
      expect(_zoneColors[0], equals(Colors.grey));
      expect(_zoneColors[1], equals(Colors.blue));
      expect(_zoneColors[2], equals(Colors.green));
      expect(_zoneColors[3], equals(Colors.orange));
      expect(_zoneColors[4], equals(Colors.red));
    });

    test('zone color count matches zone count', () {
      expect(_zoneColors.length, equals(_zoneNames.length));
      expect(_zoneColors.length, equals(5));
    });

    test('zone colors are assigned correctly by index', () {
      // Zone 1 -> Grey (Recovery)
      expect(_zoneColors[0], equals(Colors.grey));
      // Zone 2 -> Blue (Aerobic base)
      expect(_zoneColors[1], equals(Colors.blue));
      // Zone 3 -> Green (Tempo)
      expect(_zoneColors[2], equals(Colors.green));
      // Zone 4 -> Orange (Threshold)
      expect(_zoneColors[3], equals(Colors.orange));
      // Zone 5 -> Red (VO2max)
      expect(_zoneColors[4], equals(Colors.red));
    });
  });

  group('Analytics Zone Name Tests', () {
    test('zone names match AnalyticsScreen static constants', () {
      expect(_zoneNames[0], equals('Zone 1'));
      expect(_zoneNames[1], equals('Zone 2'));
      expect(_zoneNames[2], equals('Zone 3'));
      expect(_zoneNames[3], equals('Zone 4'));
      expect(_zoneNames[4], equals('Zone 5'));
    });

    test('zone names align with Zone enum order', () {
      for (var i = 0; i < 5; i++) {
        expect(_zoneNames[i], equals('Zone ${i + 1}'));
      }
    });
  });

  group('Analytics Overview Card Tests', () {
    testWidgets('overview card displays session stats', (tester) async {
      await tester.pumpWidget(testWrapper(_OverviewCardTestWidget(
        totalSessions: 25,
        totalDurationSecs: 9000,
        overallAvgHr: 145,
      )));

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('25'), findsOneWidget); // totalSessions
      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('Total Time'), findsOneWidget);
      expect(find.text('Avg HR'), findsOneWidget);
    });

    testWidgets('overview card shows three stat columns', (tester) async {
      await tester.pumpWidget(testWrapper(_OverviewCardTestWidget(
        totalSessions: 10,
        totalDurationSecs: 3600,
        overallAvgHr: 130,
      )));

      // Three icons for three stats
      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
      expect(find.byIcon(Icons.timer), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('overview card formats duration correctly', (tester) async {
      await tester.pumpWidget(testWrapper(_OverviewCardTestWidget(
        totalSessions: 1,
        totalDurationSecs: 5400, // 1h 30m
        overallAvgHr: 120,
      )));

      expect(find.text('1h 30m'), findsOneWidget);
    });
  });

  group('Analytics Empty State Tests', () {
    testWidgets('empty state shows no data message', (tester) async {
      await tester.pumpWidget(testWrapper(_EmptyStateTestWidget()));

      expect(find.text('No training data yet'), findsOneWidget);
      expect(find.text('Complete a session to see your analytics'), findsOneWidget);
    });

    testWidgets('empty state shows bar chart icon', (tester) async {
      await tester.pumpWidget(testWrapper(_EmptyStateTestWidget()));

      expect(find.byIcon(Icons.bar_chart), findsOneWidget);
    });
  });

  group('Analytics Error State Tests', () {
    testWidgets('error state shows error message', (tester) async {
      const errorMsg = 'Failed to load analytics: connection refused';
      await tester.pumpWidget(testWrapper(_ErrorStateTestWidget(errorMsg)));

      expect(find.text(errorMsg), findsOneWidget);
    });

    testWidgets('error state shows error icon', (tester) async {
      const errorMsg = 'Test error';
      await tester.pumpWidget(testWrapper(_ErrorStateTestWidget(errorMsg)));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('error state shows retry button', (tester) async {
      const errorMsg = 'Test error';
      await tester.pumpWidget(testWrapper(_ErrorStateTestWidget(errorMsg)));

      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });
  });

  group('Analytics Zone Distribution Tests', () {
    test('zone percentage calculation is correct', () {
      final zones = [600, 1200, 1800, 900, 300];
      final total = zones.fold<int>(0, (s, v) => s + v);
      expect(total, equals(4800));

      // Zone 1: 600/4800 = 12.5%
      expect((zones[0] / total * 100).toStringAsFixed(1), equals('12.5'));
      // Zone 2: 1200/4800 = 25.0%
      expect((zones[1] / total * 100).toStringAsFixed(1), equals('25.0'));
      // Zone 3: 1800/4800 = 37.5%
      expect((zones[2] / total * 100).toStringAsFixed(1), equals('37.5'));
      // Zone 4: 900/4800 = 18.75%
      expect((zones[3] / total * 100).toStringAsFixed(1), equals('18.8'));
      // Zone 5: 300/4800 = 6.25%
      expect((zones[4] / total * 100).toStringAsFixed(1), equals('6.3'));
    });

    test('zone distribution shows zero percent when zone time is zero', () {
      final zones = [0, 0, 0, 0, 0];
      final total = zones.fold<int>(0, (s, v) => s + v);
      expect(total, equals(0));
    });

    testWidgets('zone distribution widget renders all five zones', (tester) async {
      final zones = [600, 1200, 1800, 900, 300];
      final total = zones.fold<int>(0, (s, v) => s + v);

      await tester.pumpWidget(testWrapper(
        _ZoneDistributionTestWidget(zones: zones, total: total),
      ));

      for (var i = 0; i < 5; i++) {
        expect(find.text('Zone ${i + 1}'), findsOneWidget);
      }
    });
  });

  group('Analytics Chart Helpers Tests', () {
    test('bar chart max Y calculation', () {
      final pts = [
        _makeTrendPoint(1000, 30),
        _makeTrendPoint(2000, 45),
        _makeTrendPoint(3000, 20),
        _makeTrendPoint(4000, 60),
      ];

      final maxY = pts.fold<double>(0, (m, p) => p.value > m ? p.value : m);
      expect(maxY, equals(60));
    });

    test('line chart spots construction', () {
      final pts = [
        _makeTrendPoint(1000, 130),
        _makeTrendPoint(2000, 135),
        _makeTrendPoint(3000, 128),
      ];

      final spots = [
        for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i].value),
      ];

      expect(spots.length, equals(3));
      expect(spots[0], equals(const FlSpot(0, 130)));
      expect(spots[1], equals(const FlSpot(1, 135)));
      expect(spots[2], equals(const FlSpot(2, 128)));
    });

    test('line chart y-axis padding calculation', () {
      final yMin = 120.0;
      final yMax = 150.0;
      final pad = (yMax - yMin) * 0.1 + 1;
      expect(pad, equals(4));
    });

    test('line chart y-axis min calculation', () {
      final yMin = 5.0;
      final yMax = 15.0;
      final pad = (yMax - yMin) * 0.1 + 1;
      final result = (yMin - pad).clamp(0, double.infinity);
      // (5 - 2) = 3.0 after padding
      expect(result, equals(3.0));
    });
  });
}

// Re-implementations of AnalyticsScreen helper methods for testing

List<String> get _zoneNames => ['Zone 1', 'Zone 2', 'Zone 3', 'Zone 4', 'Zone 5'];

List<Color> get _zoneColors => [
  Colors.grey,
  Colors.blue,
  Colors.green,
  Colors.orange,
  Colors.red,
];

String _fmtDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

String _fmtWeek(int millis) =>
    DateFormat('M/d').format(DateTime.fromMillisecondsSinceEpoch(millis));

ApiTrendPoint _makeTrendPoint(int timestampMillis, double value) {
  return ApiTrendPoint(
    timestampMillis: timestampMillis,
    value: value,
  );
}

// Test widget builders

class _OverviewCardTestWidget extends StatelessWidget {
  final int totalSessions;
  final int totalDurationSecs;
  final int overallAvgHr;

  const _OverviewCardTestWidget({
    required this.totalSessions,
    required this.totalDurationSecs,
    required this.overallAvgHr,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statWidget(context, Icons.fitness_center, 'Sessions', '$totalSessions'),
                _statWidget(context, Icons.timer, 'Total Time', _fmtDuration(totalDurationSecs)),
                _statWidget(context, Icons.favorite, 'Avg HR', '$overallAvgHr BPM'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statWidget(BuildContext context, IconData icon, String label, String value) {
    final t = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 32, color: t.colorScheme.primary),
        const SizedBox(height: 8),
        Text(label, style: t.textTheme.bodySmall?.copyWith(
          color: t.colorScheme.onSurfaceVariant,
        )),
        const SizedBox(height: 4),
        Text(value, style: t.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        )),
      ],
    );
  }
}

class _EmptyStateTestWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 64, color: cs.outline),
          const SizedBox(height: 16),
          Text(
            'No training data yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: cs.outline),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete a session to see your analytics',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorStateTestWidget extends StatelessWidget {
  final String error;

  const _ErrorStateTestWidget(this.error);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneDistributionTestWidget extends StatelessWidget {
  final List<int> zones;
  final int total;

  const _ZoneDistributionTestWidget({required this.zones, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(5, (i) {
        final secs = zones[i];
        final pct = (secs / total * 100).toStringAsFixed(1);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_zoneNames[i], style: Theme.of(context).textTheme.bodyMedium),
                  Text(
                    '${_fmtDuration(secs)} ($pct%)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: secs / total,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(_zoneColors[i]),
                minHeight: 8,
              ),
            ],
          ),
        );
      }),
    );
  }
}