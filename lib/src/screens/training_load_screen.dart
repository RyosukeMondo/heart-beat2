import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../bridge/api_generated.dart/api.dart';

/// Training load PMC (Performance Management Chart) screen showing
/// CTL (fitness), ATL (fatigue), and TSB (form) over time.
class TrainingLoadScreen extends StatefulWidget {
  const TrainingLoadScreen({super.key});

  @override
  State<TrainingLoadScreen> createState() => _TrainingLoadScreenState();
}

class _TrainingLoadScreenState extends State<TrainingLoadScreen> {
  ApiTrainingLoadData? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await getTrainingLoad();
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load training data: $e';
        _isLoading = false;
      });
    }
  }

  String _fmtDate(int millis) =>
      DateFormat('M/d').format(DateTime.fromMillisecondsSinceEpoch(millis));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Training Load')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();
    if (_data!.loadHistory.isEmpty) return _buildEmpty();
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
            ElevatedButton.icon(
              onPressed: _loadData,
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
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 64, color: cs.outline),
          const SizedBox(height: 16),
          Text(
            'No training load data yet',
            style: tt.titleLarge?.copyWith(color: cs.outline),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete a few sessions to see your fitness trends',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
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
          _buildMetricCards(),
          _buildPmcChart(),
          if (_data!.sessionTrimp.isNotEmpty) _buildTrimpChart(),
          _buildLegend(),
          _buildInfoCard(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMetricCards() {
    final d = _data!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _metricCard('CTL', d.currentCtl, 'Fitness', Colors.blue),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _metricCard('ATL', d.currentAtl, 'Fatigue', Colors.red),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _metricCard(
              'TSB',
              d.currentTsb,
              'Form',
              d.currentTsb >= 0 ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard(
    String label,
    double value,
    String subtitle,
    Color accent,
  ) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text(
              label,
              style: t.textTheme.bodySmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value.toStringAsFixed(0),
              style: t.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPmcChart() {
    return _chartCard(
      'Performance Management Chart',
      'Fitness, fatigue and form over time',
      SizedBox(height: 280, child: _pmcLineChart()),
    );
  }

  Widget _pmcLineChart() {
    final history = _data!.loadHistory;
    final ctlSpots = <FlSpot>[];
    final atlSpots = <FlSpot>[];
    final tsbSpots = <FlSpot>[];
    for (var i = 0; i < history.length; i++) {
      final p = history[i];
      ctlSpots.add(FlSpot(i.toDouble(), p.ctl));
      atlSpots.add(FlSpot(i.toDouble(), p.atl));
      tsbSpots.add(FlSpot(i.toDouble(), p.tsb));
    }
    final allVals = [
      ...history.map((p) => p.ctl),
      ...history.map((p) => p.atl),
      ...history.map((p) => p.tsb),
    ];
    final yMin = allVals.fold<double>(double.infinity, (m, v) => v < m ? v : m);
    final yMax = allVals.fold<double>(
      double.negativeInfinity,
      (m, v) => v > m ? v : m,
    );
    final pad = (yMax - yMin) * 0.1 + 1;

    return LineChart(
      LineChartData(
        gridData: _grid(),
        titlesData: _dateTitles(
          history.length,
          (i) => _fmtDate(history[i].timestampMillis.toInt()),
        ),
        borderData: _border(),
        minX: 0,
        maxX: (history.length - 1).toDouble(),
        minY: yMin - pad,
        maxY: yMax + pad,
        lineBarsData: [
          _solidLine(ctlSpots, Colors.blue),
          _solidLine(atlSpots, Colors.red),
          _tsbLine(tsbSpots),
        ],
        lineTouchData: _pmcTouch(),
      ),
    );
  }

  LineChartBarData _solidLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(show: spots.length <= 20),
      belowBarData: BarAreaData(show: false),
    );
  }

  LineChartBarData _tsbLine(List<FlSpot> spots) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: Colors.green,
      barWidth: 2,
      isStrokeCapRound: true,
      dashArray: [8, 4],
      dotData: FlDotData(show: spots.length <= 20),
      belowBarData: BarAreaData(
        show: true,
        color: Colors.green.withValues(alpha: 0.15),
        cutOffY: 0,
        applyCutOffY: true,
      ),
      aboveBarData: BarAreaData(
        show: true,
        color: Colors.red.withValues(alpha: 0.15),
        cutOffY: 0,
        applyCutOffY: true,
      ),
    );
  }

  LineTouchData _pmcTouch() {
    final labels = ['CTL', 'ATL', 'TSB'];
    final colors = [Colors.blue, Colors.red, Colors.green];
    final history = _data!.loadHistory;
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) =>
            Theme.of(context).colorScheme.surfaceContainerHighest,
        getTooltipItems: (spots) => spots.map((s) {
          final i = s.x.toInt();
          final idx = spots.indexOf(s);
          final date = i < history.length
              ? _fmtDate(history[i].timestampMillis.toInt())
              : '';
          return LineTooltipItem(
            '${idx == 0 ? '$date\n' : ''}${labels[idx]}: ${s.y.toStringAsFixed(1)}',
            TextStyle(color: colors[idx], fontWeight: FontWeight.bold),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrimpChart() {
    return _chartCard(
      'TRIMP per Session',
      'Training impulse by session',
      SizedBox(height: 200, child: _trimpBarChart()),
    );
  }

  Widget _trimpBarChart() {
    final trimp = _data!.sessionTrimp;
    final maxY = trimp.fold<double>(0, (m, p) => p.value > m ? p.value : m);
    final groups = List.generate(
      trimp.length,
      (i) => BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: trimp[i].value,
            color: _trimpColor(trimp[i].value),
            width: trimp.length > 12 ? 8 : 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      ),
    );
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barGroups: groups,
        gridData: _grid(),
        titlesData: _dateTitles(
          trimp.length,
          (i) => _fmtDate(trimp[i].timestampMillis.toInt()),
        ),
        borderData: _border(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) =>
                Theme.of(context).colorScheme.surfaceContainerHighest,
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${_fmtDate(trimp[group.x].timestampMillis.toInt())}\nTRIMP: ${rod.toY.toInt()}',
              TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _trimpColor(double trimp) {
    if (trimp < 50) return Colors.green;
    if (trimp <= 150) return Colors.orange;
    return Colors.red;
  }

  FlTitlesData _dateTitles(int count, String Function(int) labelAt) {
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
            if (i < 0 || i >= count) return const SizedBox.shrink();
            if (count > 8 && i % 2 != 0) return const SizedBox.shrink();
            return Text(
              labelAt(i),
              style: Theme.of(context).textTheme.bodySmall,
            );
          },
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return _chartCard(
      'Legend',
      'What the metrics mean',
      Column(
        children: [
          _legendRow(
            Colors.blue,
            'CTL (Chronic Training Load)',
            'Your fitness level -- rolling average of training stress',
          ),
          const SizedBox(height: 8),
          _legendRow(
            Colors.red,
            'ATL (Acute Training Load)',
            'Recent training stress -- short-term fatigue',
          ),
          const SizedBox(height: 8),
          _legendRow(
            Colors.green,
            'TSB (Training Stress Balance)',
            'Form/freshness -- difference between fitness and fatigue',
          ),
        ],
      ),
    );
  }

  Widget _legendRow(Color color, String title, String description) {
    final t = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: t.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                description,
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: Icon(Icons.info_outline, color: t.colorScheme.primary),
        title: Text(
          'Understanding Your Training Load',
          style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(
                  Icons.check_circle,
                  Colors.green,
                  'TSB > 0: You\'re fresh and well-rested',
                ),
                const SizedBox(height: 8),
                _infoRow(
                  Icons.trending_flat,
                  Colors.orange,
                  'TSB -10 to 0: Optimal training zone',
                ),
                const SizedBox(height: 8),
                _infoRow(
                  Icons.warning,
                  Colors.red,
                  'TSB < -20: Risk of overtraining, consider recovery',
                ),
                const SizedBox(height: 12),
                Text(
                  'The PMC chart helps you balance training stress with '
                  'recovery. Rising CTL means improving fitness, while a '
                  'very negative TSB indicates accumulated fatigue that '
                  'may require rest.',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
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
