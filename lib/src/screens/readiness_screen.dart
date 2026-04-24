import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../bridge/api_generated.dart/api.dart';

/// Morning readiness check and recovery score display.
class ReadinessScreen extends StatefulWidget {
  const ReadinessScreen({super.key});

  @override
  State<ReadinessScreen> createState() => _ReadinessScreenState();
}

class _ReadinessScreenState extends State<ReadinessScreen> {
  ApiReadinessData? _readiness;
  ApiRestingHrStats? _rhrStats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReadiness();
  }

  Future<void> _loadReadiness() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        getReadinessScore(),
        getRestingHrStats(),
      ]);
      if (!mounted) return;
      setState(() {
        _readiness = results[0] as ApiReadinessData;
        _rhrStats = results[1] as ApiRestingHrStats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load readiness data: $e';
        _isLoading = false;
      });
    }
  }

  Color _scoreColor() {
    final s = _readiness?.score ?? 0;
    if (s >= 70) return Colors.green;
    if (s >= 40) return Colors.orange;
    return Colors.red;
  }

  Color _componentColor(double value) {
    if (value >= 70) return Colors.green;
    if (value >= 40) return Colors.orange;
    return Colors.red;
  }

  String _fmtDate(int millis) =>
      DateFormat('M/d').format(DateTime.fromMillisecondsSinceEpoch(millis));

  String _levelLabel() {
    switch (_readiness?.level) {
      case 'Ready':
        return 'Ready to Train';
      case 'Moderate':
        return 'Moderate Recovery';
      case 'Rest':
        return 'Rest Recommended';
      default:
        return _readiness?.level ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recovery & Readiness')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();
    return _buildContent();
  }

  Widget _buildError() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadReadiness,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildScoreIndicator(),
          _buildComponentBars(),
          _buildRecommendation(),
          _buildRestingHrChart(),
          _buildMeasureButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildScoreIndicator() {
    final color = _scoreColor();
    final t = Theme.of(context);
    final score = _readiness?.score ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 12,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$score',
                    style: t.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    _levelLabel(),
                    style: t.textTheme.titleMedium?.copyWith(
                      color: t.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComponentBars() {
    final r = _readiness;
    if (r == null) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _componentBar('HRV Status', r.hrvComponent),
            const SizedBox(height: 12),
            _componentBar('Resting HR', r.rhrComponent),
            const SizedBox(height: 12),
            _componentBar('Training Load', r.loadComponent),
          ],
        ),
      ),
    );
  }

  Widget _componentBar(String label, double value) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: t.textTheme.bodyMedium),
            Text(
              '${value.toInt()}/100',
              style: t.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value / 100,
          backgroundColor: t.colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(_componentColor(value)),
          minHeight: 8,
        ),
      ],
    );
  }

  Widget _buildRecommendation() {
    final t = Theme.of(context);
    final rec = _readiness?.recommendation ?? '';
    if (rec.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: _scoreColor(), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                rec,
                style: t.textTheme.bodyMedium?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestingHrChart() {
    final pts = _rhrStats?.trendPoints ?? [];
    if (pts.isEmpty) return const SizedBox.shrink();
    return _chartCard('Resting HR Trend', 'Last 30 days', _buildLineChart(pts));
  }

  Widget _chartCard(String title, String subtitle, Widget chart) {
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: t.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            chart,
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart(List<ApiTrendPoint> pts) {
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
    final color = Theme.of(context).colorScheme.error;
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
          lineTouchData: _lineTouch(pts),
        ),
      ),
    );
  }

  LineTouchData _lineTouch(List<ApiTrendPoint> pts) {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) =>
            Theme.of(context).colorScheme.surfaceContainerHighest,
        getTooltipItems: (spots) => spots.map((s) {
          final i = s.x.toInt();
          final lbl = i < pts.length
              ? _fmtDate(pts[i].timestampMillis.toInt())
              : '';
          return LineTooltipItem(
            '$lbl\n${s.y.toStringAsFixed(1)} BPM',
            TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          );
        }).toList(),
      ),
    );
  }

  FlTitlesData _titles(List<ApiTrendPoint> pts) {
    return FlTitlesData(
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (v, meta) {
            if (v == meta.max || v == meta.min) return const SizedBox.shrink();
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
            if (pts.length > 8 && i % 5 != 0) return const SizedBox.shrink();
            return Text(
              _fmtDate(pts[i].timestampMillis.toInt()),
              style: Theme.of(context).textTheme.bodySmall,
            );
          },
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

  Widget _buildMeasureButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: FilledButton.icon(
        onPressed: _startMorningCheck,
        icon: const Icon(Icons.monitor_heart),
        label: const Text('Take Morning Measurement'),
      ),
    );
  }

  void _startMorningCheck() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _MorningCheckSheet(),
    ).then((_) {
      _loadReadiness();
    });
  }
}

class _MorningCheckSheet extends StatelessWidget {
  const _MorningCheckSheet();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: t.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(Icons.self_improvement, size: 64, color: t.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Morning Readiness Check',
              style: t.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'For the most accurate reading:\n'
              '1. Sit comfortably and relax\n'
              '2. Make sure your HR monitor is connected\n'
              '3. Stay still for 60 seconds\n'
              '4. Breathe naturally',
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Measurement'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
