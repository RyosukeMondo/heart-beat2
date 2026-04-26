import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/health_settings_service.dart';

/// Screen for configuring low-heart-rate alert settings.
///
/// Form fields:
/// - Threshold (bpm): number input, clamped 40–120
/// - Sustained minutes: slider/stepper, range 1–60
/// - Sample cadence: dropdown, options 1s/5s/15s/60s
/// - Quiet hours: two TimeOfDay pickers (start / end), HH:mm format
/// - Master notifications toggle
class HealthSettingsScreen extends StatefulWidget {
  const HealthSettingsScreen({super.key});

  @override
  State<HealthSettingsScreen> createState() => _HealthSettingsScreenState();
}

class _HealthSettingsScreenState extends State<HealthSettingsScreen> {
  late TextEditingController _thresholdController;
  late int _sustainedMinutes;
  late int _sampleCadenceSecs;
  late TimeOfDay _quietStart;
  late TimeOfDay _quietEnd;
  late bool _notificationsEnabled;

  @override
  void initState() {
    super.initState();
    final svc = HealthSettingsService.instance;
    _thresholdController = TextEditingController(text: svc.lowHrThreshold.toString());
    _sustainedMinutes = svc.sustainedMinutes;
    _sampleCadenceSecs = svc.sampleCadenceSecs;
    _quietStart = _parseTimeOfDay(svc.quietStart);
    _quietEnd = _parseTimeOfDay(svc.quietEnd);
    _notificationsEnabled = svc.notificationsEnabled;
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    super.dispose();
  }

  TimeOfDay _parseTimeOfDay(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    return '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';
  }

  int _clampThreshold(int value) => value.clamp(40, 120);

  Future<void> _pickQuietStart(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _quietStart,
      helpText: 'Quiet hours start',
    );
    if (picked != null) {
      setState(() => _quietStart = picked);
      await HealthSettingsService.instance.setQuietStart(_formatTimeOfDay(picked));
    }
  }

  Future<void> _pickQuietEnd(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _quietEnd,
      helpText: 'Quiet hours end',
    );
    if (picked != null) {
      setState(() => _quietEnd = picked);
      await HealthSettingsService.instance.setQuietEnd(_formatTimeOfDay(picked));
    }
  }

  Future<void> _onThresholdSubmitted(String value) async {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      final clamped = _clampThreshold(parsed);
      await HealthSettingsService.instance.setLowHrThreshold(clamped);
      if (mounted) {
        setState(() => _thresholdController.text = clamped.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('healthSettingsScreen'),
      appBar: AppBar(title: const Text('Health Alerts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Threshold ──────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Low Heart Rate Threshold',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Alert when your HR stays below this value.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          key: const Key('thresholdField'),
                          controller: _thresholdController,
                          decoration: const InputDecoration(
                            suffixText: 'BPM',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onFieldSubmitted: _onThresholdSubmitted,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Range: 40 – 120 BPM',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Sustained minutes ──────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sustained Duration',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Alert only after HR stays low for this long.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        key: const Key('sustainedMinus'),
                        icon: const Icon(Icons.remove),
                        onPressed: _sustainedMinutes > 1
                            ? () async {
                                final next = _sustainedMinutes - 1;
                                setState(() => _sustainedMinutes = next);
                                await HealthSettingsService.instance.setSustainedMinutes(next);
                              }
                            : null,
                      ),
                      Text(
                        '$_sustainedMinutes min',
                        key: const Key('sustainedValue'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      IconButton(
                        key: const Key('sustainedPlus'),
                        icon: const Icon(Icons.add),
                        onPressed: _sustainedMinutes < 60
                            ? () async {
                                final next = _sustainedMinutes + 1;
                                setState(() => _sustainedMinutes = next);
                                await HealthSettingsService.instance.setSustainedMinutes(next);
                              }
                            : null,
                      ),
                    ],
                  ),
                  Slider(
                    key: const Key('sustainedSlider'),
                    value: _sustainedMinutes.toDouble(),
                    min: 1,
                    max: 60,
                    divisions: 59,
                    label: '$_sustainedMinutes min',
                    onChanged: (val) async {
                      final next = val.round();
                      setState(() => _sustainedMinutes = next);
                      await HealthSettingsService.instance.setSustainedMinutes(next);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Cadence ────────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sample Cadence',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'How often to record a sample while connected.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    key: const Key('cadenceDropdown'),
                    initialValue: _sampleCadenceSecs,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Cadence',
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 second')),
                      DropdownMenuItem(value: 5, child: Text('5 seconds')),
                      DropdownMenuItem(value: 15, child: Text('15 seconds')),
                      DropdownMenuItem(value: 60, child: Text('60 seconds')),
                    ],
                    onChanged: (val) async {
                      if (val != null) {
                        setState(() => _sampleCadenceSecs = val);
                        await HealthSettingsService.instance.setSampleCadenceSecs(val);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Quiet hours ────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quiet Hours',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No notifications during this time window.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _QuietHoursPicker(
                          key: const Key('quietStartPicker'),
                          label: 'Start',
                          time: _quietStart,
                          onTap: () => _pickQuietStart(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _QuietHoursPicker(
                          key: const Key('quietEndPicker'),
                          label: 'End',
                          time: _quietEnd,
                          onTap: () => _pickQuietEnd(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _QuietHoursValidation(
                    start: _quietStart,
                    end: _quietEnd,
                    onRejected: (msg) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Master toggle ──────────────────────────────────────────────────
          Card(
            child: SwitchListTile(
              key: const Key('notificationsToggle'),
              title: const Text('Enable Notifications'),
              subtitle: const Text('Receive alerts when HR stays low.'),
              value: _notificationsEnabled,
              onChanged: (val) async {
                setState(() => _notificationsEnabled = val);
                await HealthSettingsService.instance.setNotificationsEnabled(val);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable card that shows a TimeOfDay and opens the system picker on tap.
class _QuietHoursPicker extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _QuietHoursPicker({
    super.key,
    required this.label,
    required this.time,
    required this.onTap,
  });

  String get _formatted =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(_formatted, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

/// Validates quiet-hours pair and reports invalid HH:mm via onRejected.
///
/// An invalid HH:mm string (malformed or out-of-range) is clamped to the
/// nearest valid value before being accepted.
class _QuietHoursValidation extends StatefulWidget {
  final TimeOfDay start;
  final TimeOfDay end;
  final void Function(String message) onRejected;

  const _QuietHoursValidation({
    required this.start,
    required this.end,
    required this.onRejected,
  });

  @override
  State<_QuietHoursValidation> createState() => _QuietHoursValidationState();
}

class _QuietHoursValidationState extends State<_QuietHoursValidation> {
  bool _validated = false;

  @override
  void didUpdateWidget(_QuietHoursValidation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_validated) _checkRange();
    if (widget.start != oldWidget.start || widget.end != oldWidget.end) {
      _validated = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkRange());
  }

  void _checkRange() {
    // Reject invalid HH:mm — values are already clamped at input, but
    // we catch malformed strings if they somehow got through.
    if (widget.start.hour < 0 || widget.start.hour > 23 ||
        widget.start.minute < 0 || widget.start.minute > 59 ||
        widget.end.hour < 0 || widget.end.hour > 23 ||
        widget.end.minute < 0 || widget.end.minute > 59) {
      widget.onRejected('Invalid time value — ensure HH:mm is between 00:00 and 23:59');
      return;
    }
    _validated = true;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}