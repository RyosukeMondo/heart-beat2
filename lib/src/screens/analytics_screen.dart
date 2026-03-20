import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../bridge/api_generated.dart/api.dart';

/// Long-term training analytics dashboard with charts and summaries.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  ApiAnalyticsData? _data;
  bool _isLoading = true;
  String? _error;

  static const _zoneNames = ['Zone 1', 'Zone 2', 'Zone 3', 'Zone 4', 'Zone 5'];
  static const _zoneColors = [
    Colors.grey,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
  ];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await getAnalytics();
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load analytics: $e';
        _isLoading = false;
      });
    }
  }

  String _fmtDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  String _fmtWeek(int millis) =>
      DateFormat('M/d').format(DateTime.fromMillisecondsSinceEpoch(millis));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();
    if (_data!.summary.totalSessions == 0) return _buildEmpty();
    return _buildContent();
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAnalytics,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 64, color: cs.outline),
          const SizedBox(height: 16),
          Text(
            'No training data yet',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: cs.outline),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete a session to see your analytics',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildOverviewCard(),
          _buildVolumeChart(),
          _buildHrTrendChart(),
          _buildZoneDistribution(),
          _buildConsistencyChart(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildOverviewCard() {
    final s = _data!.summary;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat(Icons.fitness_center, 'Sessions', '${s.totalSessions}'),
                _stat(
                  Icons.timer,
                  'Total Time',
                  _fmtDuration(s.totalDurationSecs),
                ),
                _stat(Icons.favorite, 'Avg HR', '${s.overallAvgHr} BPM'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value) {
    final t = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 32, color: t.colorScheme.primary),
        const SizedBox(height: 8),
        Text(
          label,
          style: t.textTheme.bodySmall?.copyWith(
            color: t.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildVolumeChart() {
    final pts = _data!.volumeTrend;
    if (pts.isEmpty) return const SizedBox.shrink();
    return _chartCard('Training Volume', 'Minutes per week', _barChart(pts));
  }

  Widget _barChart(List<ApiTrendPoint> pts) {
    final maxY = pts.fold<double>(0, (m, p) => p.value > m ? p.value : m);
    final groups = List.generate(
      pts.length,
      (i) => BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: pts[i].value,
            color: Theme.of(context).colorScheme.primary,
            width: pts.length > 12 ? 8 : 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      ),
    );
    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY * 1.2,
          barGroups: groups,
          gridData: _grid(),
          titlesData: _titles(pts),
          borderData: _border(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) =>
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${_fmtWeek(pts[group.x].timestampMillis.toInt())}\n'
                '${rod.toY.toInt()} min',
                TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHrTrendChart() {
    final pts = _data!.hrTrend;
    if (pts.isEmpty) return const SizedBox.shrink();
    return _chartCard(
      'Heart Rate Trend',
      'Average HR per session',
      _lineChart(pts, Theme.of(context).colorScheme.error, 'BPM'),
    );
  }

  Widget _buildConsistencyChart() {
    final pts = _data!.consistencyTrend;
    if (pts.isEmpty) return const SizedBox.shrink();
    return _chartCard(
      'Consistency',
      'Sessions per week',
      _lineChart(pts, Theme.of(context).colorScheme.tertiary, 'sessions'),
    );
  }

  Widget _lineChart(List<ApiTrendPoint> pts, Color color, String unit) {
    final spots = [
      for (var i = 0; i < pts.length; i++) FlSpot(i.toDouble(), pts[i].value),
    ];
    final yMin = spots.fold<double>(
      double.infinity,
      (m, s) => s.y < m ? s.y : m,
    );
    final yMax = spots.fold<double>(
      double.negativeInfinity,
      (m, s) => s.y > m ? s.y : m,
    );
    final pad = (yMax - yMin) * 0.1 + 1;
    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          gridData: _grid(),
          titlesData: _titles(pts),
          borderData: _border(),
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: (yMin - pad).clamp(0, double.infinity),
          maxY: yMax + pad,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: spots.length <= 20),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.15),
              ),
            ),
          ],
          lineTouchData: _lineTouch(pts, unit),
        ),
      ),
    );
  }

  LineTouchData _lineTouch(List<ApiTrendPoint> pts, String unit) {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) =>
            Theme.of(context).colorScheme.surfaceContainerHighest,
        getTooltipItems: (spots) => spots.map((s) {
          final i = s.x.toInt();
          final lbl = i < pts.length
              ? _fmtWeek(pts[i].timestampMillis.toInt())
              : '';
          return LineTooltipItem(
            '$lbl\n${s.y.toStringAsFixed(1)} $unit',
            TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Shared axis titles for bar and line charts (indexed x-axis).
  FlTitlesData _titles(List<ApiTrendPoint> pts) {
    return FlTitlesData(
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (v, meta) {
            if (v == meta.max || v == meta.min) {
              return const SizedBox.shrink();
            }
            return Text(
              '${v.toInt()}',
              style: Theme.of(context).textTheme.bodySmall,
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          getTitlesWidget: (v, meta) {
            final i = v.toInt();
            if (i < 0 || i >= pts.length) return const SizedBox.shrink();
            if (pts.length > 8 && i % 2 != 0) return const SizedBox.shrink();
            return Text(
              _fmtWeek(pts[i].timestampMillis.toInt()),
              style: Theme.of(context).textTheme.bodySmall,
            );
          },
        ),
      ),
    );
  }

  Widget _buildZoneDistribution() {
    final zones = _data!.summary.overallTimeInZone;
    final total = zones.fold<int>(0, (s, v) => s + v);
    if (total == 0) return const SizedBox.shrink();
    return _chartCard(
      'Zone Distribution',
      'Overall time in each heart rate zone',
      _zoneBars(zones, total),
    );
  }

  Widget _zoneBars(List<int> zones, int total) {
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
                  Text(
                    _zoneNames[i],
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
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
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(_zoneColors[i]),
                minHeight: 8,
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _chartCard(String title, String subtitle, Widget chart) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            chart,
          ],
        ),
      ),
    );
  }

  FlGridData _grid() => FlGridData(
    show: true,
    drawVerticalLine: false,
    getDrawingHorizontalLine: (_) => FlLine(
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
      strokeWidth: 1,
    ),
  );

  FlBorderData _border() => FlBorderData(
    show: true,
    border: Border.all(color: Theme.of(context).colorScheme.outline, width: 1),
  );
}
