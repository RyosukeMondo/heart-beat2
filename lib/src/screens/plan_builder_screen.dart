import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../bridge/api_generated.dart/api.dart' as api;

/// Local model representing a single training phase.
class _PlanPhase {
  String name;
  int zone; // 1-5
  int durationMinutes;
  int durationSeconds;

  _PlanPhase({
    this.name = 'Phase',
    this.zone = 2,
    this.durationMinutes = 5,
    this.durationSeconds = 0,
  });

  int get totalSeconds => durationMinutes * 60 + durationSeconds;
}

/// Zone colors indexed by zone number (1-5).
const _zoneColors = [
  null,
  Colors.blue,
  Colors.green,
  Colors.yellow,
  Colors.orange,
  Colors.red,
];

/// Screen for creating or editing a custom training plan.
class PlanBuilderScreen extends StatefulWidget {
  /// If provided, the screen loads and edits the existing plan.
  final String? editPlanName;

  const PlanBuilderScreen({super.key, this.editPlanName});

  @override
  State<PlanBuilderScreen> createState() => _PlanBuilderScreenState();
}

class _PlanBuilderScreenState extends State<PlanBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phases = <_PlanPhase>[];

  bool _isLoading = false;
  bool _isSaving = false;
  String? _loadError;

  bool get _isEditing => widget.editPlanName != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadPlanDetails();
    } else {
      _phases.add(_PlanPhase(name: 'Warmup', zone: 2, durationMinutes: 10));
      _phases.add(_PlanPhase(name: 'Work', zone: 4, durationMinutes: 20));
      _phases.add(_PlanPhase(name: 'Cooldown', zone: 1, durationMinutes: 10));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Load existing plan details for editing.
  Future<void> _loadPlanDetails() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final details = await api.getPlanDetails(name: widget.editPlanName!);
      if (!mounted) return;

      _nameController.text = details.name;
      _phases.clear();
      for (var i = 0; i < details.phaseNames.length; i++) {
        final totalSec = details.phaseDurations[i];
        _phases.add(
          _PlanPhase(
            name: details.phaseNames[i],
            zone: details.phaseZones[i],
            durationMinutes: totalSec ~/ 60,
            durationSeconds: totalSec % 60,
          ),
        );
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Failed to load plan: $e';
      });
    }
  }

  /// Validate and save the plan via the Rust API.
  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_phases.isEmpty) {
      _showSnackBar('Add at least one phase');
      return;
    }

    final invalidDuration = _phases.any((p) => p.totalSeconds <= 0);
    if (invalidDuration) {
      _showSnackBar('All phases must have a duration greater than 0');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await api.createCustomPlan(
        name: _nameController.text.trim(),
        phaseNames: _phases.map((p) => p.name).toList(),
        phaseZones: _phases.map((p) => p.zone).toList(),
        phaseDurations: _phases.map((p) => p.totalSeconds).toList(),
        maxHr: 180,
      );

      if (!mounted) return;
      _showSnackBar('Plan saved successfully');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error saving plan: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _addPhase() {
    setState(() {
      _phases.add(_PlanPhase());
    });
  }

  void _removePhase(int index) {
    setState(() {
      _phases.removeAt(index);
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final phase = _phases.removeAt(oldIndex);
      _phases.insert(newIndex, phase);
    });
  }

  /// Format total plan duration for display.
  String get _totalDurationLabel {
    final totalSec = _phases.fold<int>(0, (s, p) => s + p.totalSeconds);
    final mins = totalSec ~/ 60;
    final secs = totalSec % 60;
    if (secs == 0) return '${mins}m';
    return '${mins}m ${secs}s';
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_loadError != null) {
      body = _buildErrorState();
    } else {
      body = _buildForm();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Plan' : 'New Training Plan'),
      ),
      body: body,
    );
  }

  Widget _buildErrorState() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadPlanDetails,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildNameCard()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(children: [
                      Text('Phases',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      if (_phases.isNotEmpty)
                        Text('Total: $_totalDurationLabel',
                            style: Theme.of(context).textTheme.bodyMedium),
                    ]),
                  ),
                ),
                _buildPhaseList(),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: OutlinedButton.icon(
                      onPressed: _addPhase,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Phase'),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildNameCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Plan Name', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'e.g. Easy Endurance',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter a plan name'
                    : null,
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseList() {
    if (_phases.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Text(
              'No phases yet. Tap "Add Phase" below.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => _PhaseCard(
          key: ValueKey(_phases[index].hashCode),
          phase: _phases[index],
          index: index,
          onRemove: () => _removePhase(index),
          onMoveUp: index > 0 ? () => _onReorder(index, index - 1) : null,
          onMoveDown: index < _phases.length - 1
              ? () => _onReorder(index, index + 2)
              : null,
          onChanged: () => setState(() {}),
        ),
        childCount: _phases.length,
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        child: FilledButton.icon(
          onPressed: _isSaving ? null : _savePlan,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: Text(_isSaving ? 'Saving...' : 'Save Plan'),
        ),
      ),
    );
  }
}

/// Card widget for a single training phase with editing controls.
class _PhaseCard extends StatelessWidget {
  final _PlanPhase phase;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onChanged;

  const _PhaseCard({
    super.key,
    required this.phase,
    required this.index,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: phase.name,
                decoration: const InputDecoration(
                  labelText: 'Phase Name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.words,
                onChanged: (v) {
                  phase.name = v;
                  onChanged();
                },
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildZoneDropdown()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDurationFields()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: _zoneColors[phase.zone],
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Phase ${index + 1}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const Spacer(),
        if (onMoveUp != null)
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 20),
            onPressed: onMoveUp,
            tooltip: 'Move up',
            visualDensity: VisualDensity.compact,
          ),
        if (onMoveDown != null)
          IconButton(
            icon: const Icon(Icons.arrow_downward, size: 20),
            onPressed: onMoveDown,
            tooltip: 'Move down',
            visualDensity: VisualDensity.compact,
          ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: onRemove,
          tooltip: 'Remove phase',
          visualDensity: VisualDensity.compact,
          color: Theme.of(context).colorScheme.error,
        ),
      ],
    );
  }

  Widget _buildZoneDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: phase.zone,
      decoration: const InputDecoration(
        labelText: 'Zone',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: List.generate(5, (i) {
        final z = i + 1;
        return DropdownMenuItem(
          value: z,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _zoneColors[z],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text('Z$z'),
            ],
          ),
        );
      }),
      onChanged: (value) {
        if (value != null) {
          phase.zone = value;
          onChanged();
        }
      },
    );
  }

  Widget _buildDurationFields() {
    return Row(children: [
      Expanded(
        child: _intField('Min', phase.durationMinutes, (v) {
          phase.durationMinutes = v;
        }),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _intField('Sec', phase.durationSeconds, (v) {
          phase.durationSeconds = v;
        }),
      ),
    ]);
  }

  TextFormField _intField(
    String label,
    int initial,
    ValueChanged<int> update,
  ) {
    return TextFormField(
      initialValue: initial.toString(),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (v) {
        update(int.tryParse(v) ?? 0);
        onChanged();
      },
    );
  }
}
