import 'package:flutter/material.dart';
import '../bridge/api_generated.dart/api.dart' as api;

class _Phase {
  final String name;
  final int zone;
  final int mins;
  const _Phase(this.name, this.zone, this.mins);
}

class _Template {
  final String id, name, description, sport, difficulty;
  final int durationMins, phaseCount;
  final List<_Phase> phases;
  const _Template({
    required this.id,
    required this.name,
    required this.description,
    required this.sport,
    required this.difficulty,
    required this.durationMins,
    required this.phaseCount,
    this.phases = const [],
  });
}

const _zoneColors = {
  1: Colors.blue,
  2: Colors.green,
  3: Colors.yellow,
  4: Colors.orange,
  5: Colors.red,
};
const _zoneLabels = {
  1: 'Z1 Recovery',
  2: 'Z2 Endurance',
  3: 'Z3 Tempo',
  4: 'Z4 Threshold',
  5: 'Z5 VO2 Max',
};
const _sportIcons = <String, IconData>{
  'Running': Icons.directions_run,
  'Cycling': Icons.pedal_bike,
  'Swimming': Icons.pool,
  'General': Icons.fitness_center,
};

// Hardcoded fallback templates for when API is not available.
// ignore_for_file: lines_longer_than_80_chars
const _defaults = <_Template>[
  _Template(
    id: 'easy-recovery',
    name: 'Easy Recovery',
    sport: 'General',
    difficulty: 'Beginner',
    durationMins: 30,
    phaseCount: 1,
    description:
        'Light recovery session to promote blood flow and aid recovery.',
    phases: [_Phase('Recovery', 1, 30)],
  ),
  _Template(
    id: 'base-endurance',
    name: 'Base Endurance',
    sport: 'Running',
    difficulty: 'Beginner',
    durationMins: 45,
    phaseCount: 3,
    description: 'Steady aerobic effort to build your endurance foundation.',
    phases: [
      _Phase('Warmup', 1, 10),
      _Phase('Endurance', 2, 25),
      _Phase('Cooldown', 1, 10),
    ],
  ),
  _Template(
    id: 'tempo-run',
    name: 'Tempo Run',
    sport: 'Running',
    difficulty: 'Intermediate',
    durationMins: 40,
    phaseCount: 3,
    description: 'Sustained tempo effort to improve lactate threshold.',
    phases: [
      _Phase('Warmup', 2, 10),
      _Phase('Tempo', 3, 20),
      _Phase('Cooldown', 1, 10),
    ],
  ),
  _Template(
    id: 'threshold-intervals',
    name: 'Threshold Intervals',
    sport: 'Running',
    difficulty: 'Intermediate',
    durationMins: 45,
    phaseCount: 11,
    description: 'Structured threshold repeats with recovery between efforts.',
    phases: [
      _Phase('Warmup', 2, 10),
      _Phase('Interval 1', 4, 4),
      _Phase('Recovery', 1, 2),
      _Phase('Interval 2', 4, 4),
      _Phase('Recovery', 1, 2),
      _Phase('Interval 3', 4, 4),
      _Phase('Recovery', 1, 2),
      _Phase('Interval 4', 4, 4),
      _Phase('Recovery', 1, 2),
      _Phase('Interval 5', 4, 4),
      _Phase('Cooldown', 1, 7),
    ],
  ),
  _Template(
    id: 'vo2-intervals',
    name: 'VO2 Max Intervals',
    sport: 'Running',
    difficulty: 'Advanced',
    durationMins: 35,
    phaseCount: 12,
    description: 'High-intensity intervals to push your aerobic ceiling.',
    phases: [
      _Phase('Warmup', 2, 8),
      _Phase('VO2 1', 5, 2),
      _Phase('Recovery', 1, 2),
      _Phase('VO2 2', 5, 2),
      _Phase('Recovery', 1, 2),
      _Phase('VO2 3', 5, 2),
      _Phase('Recovery', 1, 2),
      _Phase('VO2 4', 5, 2),
      _Phase('Recovery', 1, 2),
      _Phase('VO2 5', 5, 2),
      _Phase('Recovery', 1, 2),
      _Phase('Cooldown', 1, 5),
    ],
  ),
  _Template(
    id: 'pyramid',
    name: 'Pyramid Intervals',
    sport: 'Running',
    difficulty: 'Advanced',
    durationMins: 50,
    phaseCount: 7,
    description: 'Ascending then descending intensity for varied stimulus.',
    phases: [
      _Phase('Warmup', 2, 10),
      _Phase('Build', 3, 6),
      _Phase('Climb', 4, 6),
      _Phase('Peak', 5, 6),
      _Phase('Descend', 4, 6),
      _Phase('Settle', 3, 6),
      _Phase('Cooldown', 1, 10),
    ],
  ),
  _Template(
    id: 'sweet-spot',
    name: 'Cycling Sweet Spot',
    sport: 'Cycling',
    difficulty: 'Intermediate',
    durationMins: 60,
    phaseCount: 3,
    description:
        'Sustained effort at the boundary of tempo and threshold zones.',
    phases: [
      _Phase('Warmup', 2, 15),
      _Phase('Sweet Spot', 3, 30),
      _Phase('Cooldown', 1, 15),
    ],
  ),
  _Template(
    id: 'long-endurance',
    name: 'Long Endurance',
    sport: 'Running',
    difficulty: 'Intermediate',
    durationMins: 90,
    phaseCount: 3,
    description: 'Extended low-intensity session for building aerobic base.',
    phases: [
      _Phase('Warmup', 1, 15),
      _Phase('Endurance', 2, 60),
      _Phase('Cooldown', 1, 15),
    ],
  ),
];

/// Browsable library of curated workout templates.
class WorkoutLibraryScreen extends StatefulWidget {
  const WorkoutLibraryScreen({super.key});

  @override
  State<WorkoutLibraryScreen> createState() => _WorkoutLibraryScreenState();
}

class _WorkoutLibraryScreenState extends State<WorkoutLibraryScreen> {
  List<_Template> _templates = [];
  String? _selectedSport;
  String? _selectedDifficulty;
  bool _isLoading = true;
  String? _error;

  static const _sports = ['Running', 'Cycling', 'Swimming', 'General'];
  static const _difficulties = ['Beginner', 'Intermediate', 'Advanced', 'Custom'];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final apiTemplates = await api.getWorkoutTemplates();
      // Load user-created plans and merge them in
      final planNames = await api.listPlans();
      final planDetails = await Future.wait(
        planNames.map((name) => api.getPlanDetails(name: name)),
      );
      if (!mounted) return;

      final fromApi = apiTemplates
          .map(
            (t) => _Template(
              id: t.id,
              name: t.name,
              description: t.description,
              sport: t.sport,
              difficulty: t.difficulty,
              durationMins: t.durationMins,
              phaseCount: t.phaseCount,
            ),
          )
          .toList();
      // Convert plans to templates, avoiding ID collisions with API templates
      final apiIds = fromApi.map((t) => t.id).toSet();
      final fromPlans = planDetails
          .where((p) => !apiIds.contains('plan-${p.name}'))
          .map(
            (p) => _Template(
              id: 'plan-${p.name}',
              name: p.name,
              description: 'Custom plan',
              sport: 'General',
              difficulty: 'Custom',
              durationMins: p.phaseDurations.fold(0, (s, d) => s + d) ~/ 60,
              phaseCount: p.phaseNames.length,
            ),
          )
          .toList();
      // Merge: API templates + custom plans + missing defaults
      final ids = {...fromApi.map((t) => t.id), ...fromPlans.map((t) => t.id)};
      final merged = [
        ...fromApi,
        ...fromPlans,
        ..._defaults.where((t) => !ids.contains(t.id)),
      ];
      setState(() {
        _templates = merged;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _templates = List.of(_defaults);
        _isLoading = false;
      });
    }
  }

  List<_Template> get _filteredTemplates {
    return _templates.where((t) {
      if (_selectedSport != null && t.sport != _selectedSport) {
        return false;
      }
      if (_selectedDifficulty != null && t.difficulty != _selectedDifficulty) {
        return false;
      }
      return true;
    }).toList();
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _saveAsPlan(_Template t) async {
    try {
      await api.createCustomPlan(
        name: t.name,
        phaseNames: t.phases.map((p) => p.name).toList(),
        phaseZones: t.phases.map((p) => p.zone).toList(),
        phaseDurations: t.phases.map((p) => p.mins * 60).toList(),
        maxHr: 180,
      );
      if (!mounted) return;
      _showSnackBar('Saved "${t.name}" as a plan');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error saving plan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout Library')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();
    return Column(
      children: [
        _buildFilterChips(),
        const Divider(height: 1),
        Expanded(child: _buildTemplateList()),
      ],
    );
  }

  Widget _buildError() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
              onPressed: _loadTemplates,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chipRow(
            _sports,
            _selectedSport,
            (v) => setState(() => _selectedSport = v),
          ),
          const SizedBox(height: 8),
          _chipRow(
            _difficulties,
            _selectedDifficulty,
            (v) => setState(() => _selectedDifficulty = v),
          ),
        ],
      ),
    );
  }

  Widget _chipRow(List<String> opts, String? sel, ValueChanged<String?> cb) {
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          label: const Text('All'),
          selected: sel == null,
          onSelected: (_) => cb(null),
        ),
        for (final o in opts)
          FilterChip(
            label: Text(o),
            selected: sel == o,
            onSelected: (s) => cb(s ? o : null),
          ),
      ],
    );
  }

  Widget _buildTemplateList() {
    final list = _filteredTemplates;
    if (list.isEmpty) return _buildEmpty();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: list.length,
      itemBuilder: (_, i) => _buildTemplateCard(list[i]),
    );
  }

  Widget _buildEmpty() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              'No templates match your filters',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: cs.outline),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting the filters above.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(_Template t) {
    final cs = Theme.of(context).colorScheme;
    final icon = _sportIcons[t.sport] ?? Icons.fitness_center;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(t),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 28, color: cs.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      t.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${t.difficulty}  ${t.durationMins} min  ${t.phaseCount} phases',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                t.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => _saveAsPlan(t),
                    child: const Text('Save as Plan'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/workout/${t.id}'),
                    child: const Text('Start'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(_Template t) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _DetailSheet(
        template: t,
        onStart: () {
          Navigator.pop(ctx);
          Navigator.pushNamed(context, '/workout/${t.id}');
        },
        onSave: () {
          Navigator.pop(ctx);
          _saveAsPlan(t);
        },
      ),
    );
  }
}

/// Bottom sheet showing expanded template details and phase breakdown.
class _DetailSheet extends StatelessWidget {
  final _Template template;
  final VoidCallback onStart;
  final VoidCallback onSave;
  const _DetailSheet({
    required this.template,
    required this.onStart,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final icon = _sportIcons[template.sport] ?? Icons.fitness_center;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(icon, size: 32, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${template.difficulty}  ${template.durationMins} min  ${template.phaseCount} phases',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(template.description, style: tt.bodyLarge),
          const SizedBox(height: 20),
          Text(
            'Phase Breakdown',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (template.phases.isEmpty)
            Text(
              '${template.phaseCount} phases',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            )
          else
            ...template.phases.map((p) => _phaseRow(context, p)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Save as Plan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Workout'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _phaseRow(BuildContext context, _Phase p) {
    final color = _zoneColors[p.zone] ?? Colors.grey;
    final label = _zoneLabels[p.zone] ?? 'Z${p.zone}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(p.name, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 48,
            child: Text(
              '${p.mins}m',
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
