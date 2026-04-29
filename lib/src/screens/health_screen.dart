import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/hr_history_service.dart';
import '../services/health_alert_service.dart';

/// A single HR sample with resolved BPM and timestamp for synchronous access.
class _SamplePoint {
  final int bpm;
  final int tsMs;

  _SamplePoint({required this.bpm, required this.tsMs});
}

/// Health screen showing rolling HR averages over 1h / 24h / 7d.
///
/// Tiles call [HrHistoryService.rollingAvg] on init and on pull-to-refresh.
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  static const _window1h = 3600;
  static const _window24h = 86400;
  static const _window7d = 604800;
  static const _liveBpmInterval = Duration(seconds: 2);

  double? _avg1h;
  double? _avg24h;
  double? _avg7d;
  bool _isLoading = true;

  // Sparkline state
  List<FlSpot> _sparklineSpots = [];
  int? _liveBpm;
  bool _sparklineLoading = true;
  Timer? _liveBpmTimer;

  // Status banner state — reads from HealthAlertService state stream.
  _RuleStatus _ruleStatus = _RuleStatus.ok;
  String _ruleStatusDetail = '';
  StreamSubscription<HealthAlertState>? _cueSubscription;

  @override
  void initState() {
    super.initState();
    _loadAverages();
    _loadSparklineData();
    _startLiveBpmPolling();
    _startCueListener();
  }

  @override
  void dispose() {
    _liveBpmTimer?.cancel();
    _cueSubscription?.cancel();
    super.dispose();
  }

  void _startCueListener() {
    _cueSubscription = HealthAlertService.instance.healthAlertStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _ruleStatus = state.status == HealthRuleStatus.ok ? _RuleStatus.ok : _RuleStatus.low;
        _ruleStatusDetail = state.detail;
      });
    });
  }

  void _startLiveBpmPolling() {
    _liveBpmTimer = Timer.periodic(_liveBpmInterval, (_) async {
      final sample = await HrHistoryService.instance.latestSample();
      if (!mounted) return;
      int? bpm;
      if (sample != null) {
        bpm = await HrHistoryService.instance.apiSampleBpm(sample: sample);
      }
      if (!mounted) return;
      setState(() {
        _liveBpm = bpm;
      });
    });
  }

  Future<void> _loadAverages() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      HrHistoryService.instance.rollingAvg(windowSecs: _window1h),
      HrHistoryService.instance.rollingAvg(windowSecs: _window24h),
      HrHistoryService.instance.rollingAvg(windowSecs: _window7d),
    ]);
    if (!mounted) return;
    setState(() {
      _avg1h = results[0];
      _avg24h = results[1];
      _avg7d = results[2];
      _isLoading = false;
    });
  }

  /// Loads 24h of samples and downsamples to ~288 points (5-min buckets).
  Future<void> _loadSparklineData() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final start = now - (24 * 3600 * 1000);
    final samples = await HrHistoryService.instance.samplesInRange(
      startMs: start,
      endMs: now,
    );
    if (!mounted) return;

    // Resolve BPM and timestamp for each sample in a single parallel batch.
    final resolved = await Future.wait(
      samples.map((s) async => _SamplePoint(
        bpm: await HrHistoryService.instance.apiSampleBpm(sample: s),
        tsMs: (await HrHistoryService.instance.apiSampleTsMs(sample: s)).toInt(),
      )),
    );

    if (!mounted) return;
    setState(() {
      _sparklineSpots = _downsample(resolved, 288);
      _sparklineLoading = false;
    });
  }

  /// Downsamples [points] to at most [maxPoints] FlSpots using 5-min buckets.
  List<FlSpot> _downsample(List<_SamplePoint> points, int maxPoints) {
    if (points.isEmpty) return [];

    // Sort chronologically just in case
    points.sort((a, b) => a.tsMs.compareTo(b.tsMs));

    // Determine the time span
    final tStart = points.first.tsMs;
    final tEnd = points.last.tsMs;
    final duration = tEnd - tStart;
    if (duration <= 0) return [];

    // Bucket width = total duration / maxPoints, minimum 5 minutes
    final bucketWidthMs = duration ~/ maxPoints;
    const minBucket = 5 * 60 * 1000; // 5 minutes in ms
    final actualBucket = bucketWidthMs < minBucket ? minBucket : bucketWidthMs;

    final buckets = <int, List<int>>{};
    for (final p in points) {
      final bucketKey = ((p.tsMs - tStart) ~/ actualBucket) * actualBucket + tStart;
      buckets.putIfAbsent(bucketKey, () => []).add(p.bpm);
    }

    final sortedKeys = buckets.keys.toList()..sort();
    return sortedKeys.map((ts) {
      final vals = buckets[ts]!;
      final avg = vals.reduce((a, b) => a + b) / vals.length;
      // x = seconds from start
      return FlSpot(((ts - tStart) / 1000.0), avg);
    }).toList();
  }

  String _formatAvg(double? avg) {
    if (avg == null) return '—';
    return '${avg.toStringAsFixed(0)} BPM';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health')),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadAverages();
          await _loadSparklineData();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusBanner(status: _ruleStatus, detail: _ruleStatusDetail),
            const SizedBox(height: 16),
            _AverageCard(
              label: '1 Hour',
              avg: _avg1h,
              isLoading: _isLoading,
              onFormat: _formatAvg,
            ),
            const SizedBox(height: 12),
            _AverageCard(
              label: '24 Hours',
              avg: _avg24h,
              isLoading: _isLoading,
              onFormat: _formatAvg,
            ),
            const SizedBox(height: 12),
            _AverageCard(
              label: '7 Days',
              avg: _avg7d,
              isLoading: _isLoading,
              onFormat: _formatAvg,
            ),
            const SizedBox(height: 24),
            _buildSparklineSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSparklineSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '24h Heart Rate',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (_liveBpm != null)
                  Text(
                    '$_liveBpm BPM',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: _buildSparklineChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSparklineChart() {
    if (_sparklineLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final spots = List<FlSpot>.from(_sparklineSpots);

    // Append live BPM as rightmost point
    if (_liveBpm != null && spots.isNotEmpty) {
      final lastX = spots.last.x;
      spots.add(FlSpot(lastX + 10, _liveBpm!.toDouble()));
    }

    if (spots.isEmpty) {
      return Center(
        child: Text(
          'No heart rate data yet',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      );
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY) * 0.15).clamp(5.0, 30.0);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 20,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                // Show "0h", "12h", "24h"
                final hours = value / 3600;
                if (hours == 0 || hours == 12 || hours == 24) {
                  return Text(
                    '${hours.toInt()}h',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
        ),
        minX: 0,
        maxX: 24 * 3600.0,
        minY: (minY - pad).clamp(0, double.infinity),
        maxY: maxY + pad,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                Theme.of(context).colorScheme.surfaceContainerHighest,
            getTooltipItems: (spots) => spots.map((s) {
              final hours = (s.x / 3600).toStringAsFixed(1);
              return LineTooltipItem(
                '${hours}h\n${s.y.toInt()} BPM',
                TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _AverageCard extends StatelessWidget {
  final String label;
  final double? avg;
  final bool isLoading;
  final String Function(double?) onFormat;

  const _AverageCard({
    required this.label,
    required this.avg,
    required this.isLoading,
    required this.onFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                onFormat(avg),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: avg == null
                          ? Theme.of(context).colorScheme.outline
                          : Theme.of(context).colorScheme.primary,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _RuleStatus { ok, low }

class _StatusBanner extends StatelessWidget {
  final _RuleStatus status;
  final String detail;

  const _StatusBanner({required this.status, required this.detail});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      _RuleStatus.ok => (Colors.green, 'OK'),
      _RuleStatus.low => (Colors.amber, detail),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(Icons.favorite, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
