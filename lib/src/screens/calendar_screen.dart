import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../bridge/api_generated.dart/api.dart';

const _blockColors = <String, Color>{
  'Base': Colors.blue,
  'Build': Colors.orange,
  'Peak': Colors.red,
  'Taper': Colors.green,
  'Recovery': Colors.grey,
};

const _weeklySchedule = [
  'Easy Run',
  'Rest Day',
  'Tempo Run',
  'Rest Day',
  'Intervals',
  'Long Run',
  'Rest Day',
];

/// Periodized training calendar showing blocks and scheduled sessions.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  ApiPeriodizationData? _plan;
  late DateTime _weekStart = _monday(DateTime.now());
  List<_Session> _sessions = [];
  double _compliance = 0;
  bool _loading = true;
  String? _error;

  static DateTime _monday(DateTime d) =>
      d.subtract(Duration(days: d.weekday - 1));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plan = await getPeriodizationPlan();
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _weekStart = _monday(DateTime.now());
        _refreshSessions();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load: $e';
        _loading = false;
      });
    }
  }

  void _refreshSessions() {
    final now = DateTime.now();
    _sessions = List.generate(7, (i) {
      final d = _weekStart.add(Duration(days: i));
      return _Session(
        d,
        _weeklySchedule[i],
        _weeklySchedule[i] != 'Rest Day' && d.isBefore(now),
      );
    });
    final scheduled = _sessions.where((x) => x.workout != 'Rest Day');
    _compliance = scheduled.isEmpty
        ? 0
        : scheduled.where((x) => x.done).length / scheduled.length;
  }

  int get _weekNumber {
    if (_plan == null) return 0;
    final startDate = DateTime.tryParse(_plan!.startDate);
    if (startDate == null) return 0;
    return (_weekStart.difference(startDate).inDays ~/ 7) + 1;
  }

  int get _totalWeeks => _plan?.totalWeeks ?? 0;

  String get _currentBlockName {
    final plan = _plan;
    if (plan == null) return 'Complete';
    var w = 0;
    for (var i = 0; i < plan.blockNames.length; i++) {
      w += plan.blockWeeks[i];
      if (_weekNumber <= w) return '${plan.blockNames[i]} Phase';
    }
    return 'Complete';
  }

  double get _progress =>
      _totalWeeks == 0 ? 0 : (_weekNumber / _totalWeeks).clamp(0.0, 1.0);

  void _navigate(int direction) => setState(() {
    _weekStart = _weekStart.add(Duration(days: 7 * direction));
    _refreshSessions();
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Training Calendar')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();
    if (_plan == null) return _buildEmpty();
    return ListView(
      children: [
        _buildSummary(),
        _buildTimeline(),
        _buildWeek(),
        _buildCompliance(),
        _buildNavBar(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildError() {
    final c = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: c.error),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.error),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month, size: 64, color: c.outline),
          const SizedBox(height: 16),
          Text(
            'No training plan yet',
            style: t.titleLarge?.copyWith(color: c.outline),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a periodized plan to get started',
            style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.add),
            label: const Text('Create Training Plan'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final t = Theme.of(context);
    final df = DateFormat('MMM d');
    final p = (_progress * 100).round();
    final startDate = DateTime.tryParse(_plan!.startDate);
    final endDate = DateTime.tryParse(_plan!.endDate);
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _plan!.name,
              style: t.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Started: ${startDate != null ? df.format(startDate) : "--"}'
              ' | Ends: ${endDate != null ? df.format(endDate) : "--"}',
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Week $_weekNumber of $_totalWeeks - $_currentBlockName',
              style: t.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$p%',
                  style: t.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    final plan = _plan;
    if (plan == null || plan.blockNames.isEmpty) return const SizedBox.shrink();
    final tot = _totalWeeks;
    final cur = _weekNumber.clamp(1, tot);
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Training Blocks',
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment(((cur - 0.5) / tot) * 2 - 1, 0),
              child: Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: t.colorScheme.primary,
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: List.generate(plan.blockNames.length, (i) {
                  final color = _blockColors[plan.blockNames[i]] ?? Colors.grey;
                  return Expanded(
                    flex: plan.blockWeeks[i],
                    child: Container(
                      height: 24,
                      color: color,
                      alignment: Alignment.center,
                      child: Text(
                        '${plan.blockWeeks[i]}w',
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(plan.blockNames.length, (i) {
                final color = _blockColors[plan.blockNames[i]] ?? Colors.grey;
                return Expanded(
                  flex: plan.blockWeeks[i],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          plan.blockNames[i],
                          style: t.textTheme.labelSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeek() {
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Week of ${DateFormat("MMM d").format(_weekStart)}',
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._sessions.map((s) => _sessionRow(s, t)),
          ],
        ),
      ),
    );
  }

  Widget _sessionRow(_Session s, ThemeData t) {
    final isRest = s.workout == 'Rest Day';
    final icon = isRest
        ? Icon(Icons.remove, size: 20, color: t.colorScheme.outline)
        : s.done
        ? const Icon(Icons.check_circle, size: 20, color: Colors.green)
        : Icon(
            Icons.radio_button_unchecked,
            size: 20,
            color: t.colorScheme.onSurfaceVariant,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              DateFormat('EEE').format(s.date),
              style: t.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          icon,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.workout,
              style: t.textTheme.bodyMedium?.copyWith(
                color: isRest ? t.colorScheme.onSurfaceVariant : null,
              ),
            ),
          ),
          if (!isRest)
            Text(
              s.done ? 'Done' : 'Scheduled',
              style: t.textTheme.labelSmall?.copyWith(
                color: s.done ? Colors.green : t.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompliance() {
    final t = Theme.of(context);
    final done = _sessions
        .where((s) => s.workout != 'Rest Day' && s.done)
        .length;
    final total = _sessions.where((s) => s.workout != 'Rest Day').length;
    final p = (_compliance * 100).round();
    final color = _compliance >= 0.8
        ? Colors.green
        : _compliance >= 0.5
        ? Colors.orange
        : Colors.red;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weekly Compliance',
                  style: t.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('$p% ($done/$total)', style: t.textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _compliance,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: t.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: () => _navigate(-1),
            icon: const Icon(Icons.chevron_left),
            label: const Text('Previous Week'),
          ),
          TextButton.icon(
            onPressed: () => _navigate(1),
            icon: const Icon(Icons.chevron_right),
            label: const Text('Next Week'),
          ),
        ],
      ),
    );
  }
}

class _Session {
  final DateTime date;
  final String workout;
  final bool done;
  const _Session(this.date, this.workout, this.done);
}
