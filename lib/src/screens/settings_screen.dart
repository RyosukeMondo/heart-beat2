import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../services/audio_feedback_service.dart';
import 'zone_editor_screen.dart';

// --- Profile Settings Card ---
// Handles heart rate configuration (age, max HR, age-based calculation)

class ProfileSettingsCard extends StatelessWidget {
  final TextEditingController ageController;
  final TextEditingController maxHrController;
  final bool useAgeBased;
  final int? effectiveMaxHr;
  final ValueChanged<bool> onUseAgeBasedChanged;
  final String? Function(String?) onValidateAge;
  final String? Function(String?) onValidateMaxHr;

  const ProfileSettingsCard({
    super.key,
    required this.ageController,
    required this.maxHrController,
    required this.useAgeBased,
    required this.effectiveMaxHr,
    required this.onUseAgeBasedChanged,
    required this.onValidateAge,
    required this.onValidateMaxHr,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Heart Rate Configuration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('ageField'),
              controller: ageController,
              decoration: const InputDecoration(
                labelText: 'Age (optional)',
                helperText: 'Used for age-based max HR estimation',
                suffixText: 'years',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: onValidateAge,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              key: const Key('useAgeBasedSwitch'),
              title: const Text('Use age-based max HR'),
              subtitle: useAgeBased && ageController.text.isNotEmpty
                  ? Text('Estimated max HR: ${effectiveMaxHr ?? "--"} BPM')
                  : const Text('Enable to use age-based calculation (220 - age)'),
              value: useAgeBased,
              onChanged: ageController.text.isNotEmpty ? onUseAgeBasedChanged : null,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('maxHrField'),
              controller: maxHrController,
              decoration: InputDecoration(
                labelText: 'Maximum Heart Rate',
                helperText: useAgeBased
                    ? 'Using age-based calculation'
                    : 'Used to calculate training zones (100-220 BPM)',
                suffixText: 'BPM',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: onValidateMaxHr,
              enabled: !useAgeBased,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Audio Settings Card ---
// Handles audio feedback enable/disable and volume control

class AudioSettingsCard extends StatelessWidget {
  final bool audioFeedbackEnabled;
  final double audioVolume;
  final ValueChanged<bool> onAudioFeedbackChanged;
  final ValueChanged<double> onAudioVolumeChanged;

  const AudioSettingsCard({
    super.key,
    required this.audioFeedbackEnabled,
    required this.audioVolume,
    required this.onAudioFeedbackChanged,
    required this.onAudioVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audio Feedback',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Audio notifications during workouts for zone deviations and phase transitions',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              key: const Key('audioFeedbackEnabledSwitch'),
              title: const Text('Enable audio feedback'),
              subtitle: Text(
                audioFeedbackEnabled
                    ? 'Audio notifications enabled'
                    : 'Audio notifications disabled',
              ),
              value: audioFeedbackEnabled,
              onChanged: onAudioFeedbackChanged,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            Text('Volume', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.volume_down),
                Expanded(
                  child: Slider(
                    key: const Key('audioVolumeSlider'),
                    value: audioVolume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: '${(audioVolume * 100).round()}%',
                    onChanged: audioFeedbackEnabled ? onAudioVolumeChanged : null,
                  ),
                ),
                const Icon(Icons.volume_up),
                const SizedBox(width: 16),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${(audioVolume * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: audioFeedbackEnabled
                      ? () async {
                          await AudioFeedbackService.instance.playZoneTooHigh();
                        }
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Test Sound'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Training Zones Card ---
// Displays training zone ranges with BPM values

class TrainingZonesCard extends StatelessWidget {
  final int? effectiveMaxHr;
  final CustomZones? zones;

  const TrainingZonesCard({
    super.key,
    required this.effectiveMaxHr,
    required this.zones,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Training Zones', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  onPressed: () async {
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const ZoneEditorScreen()),
                    );
                    if (result == true) {}
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Customize'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildZoneDisplay(context),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneDisplay(BuildContext context) {
    final effectiveMaxHr = this.effectiveMaxHr;
    if (effectiveMaxHr == null) {
      return const Text('Enter max HR or age to see zone ranges');
    }

    final zones = this.zones ?? CustomZones.defaults;

    return Column(
      children: [
        _buildZoneInfo(context, 'Zone 1 (Recovery)', '0-${zones.zone1Max}%', Colors.blue, 0, zones.zone1Max, effectiveMaxHr),
        _buildZoneInfo(context, 'Zone 2 (Fat Burning)', '${zones.zone1Max}-${zones.zone2Max}%', Colors.green, zones.zone1Max, zones.zone2Max, effectiveMaxHr),
        _buildZoneInfo(context, 'Zone 3 (Aerobic)', '${zones.zone2Max}-${zones.zone3Max}%', Colors.yellow, zones.zone2Max, zones.zone3Max, effectiveMaxHr),
        _buildZoneInfo(context, 'Zone 4 (Threshold)', '${zones.zone3Max}-${zones.zone4Max}%', Colors.orange, zones.zone3Max, zones.zone4Max, effectiveMaxHr),
        _buildZoneInfo(context, 'Zone 5 (Maximum)', '${zones.zone4Max}-100%', Colors.red, zones.zone4Max, 100, effectiveMaxHr),
      ],
    );
  }

  Widget _buildZoneInfo(
    BuildContext context,
    String name,
    String percentage,
    Color color,
    int minPercent,
    int maxPercent,
    int maxHr,
  ) {
    final minBpm = (maxHr * minPercent / 100).round();
    final maxBpm = (maxHr * maxPercent / 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(name)),
          Text(
            '$percentage ($minBpm-$maxBpm BPM)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// Settings screen for user configuration
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _maxHrController = TextEditingController();
  final _ageController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _useAgeBased = false;
  bool _audioFeedbackEnabled = true;
  double _audioVolume = 0.7;
  UserProfile? _currentProfile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _maxHrController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ProfileService.instance.getProfile();
      setState(() {
        _currentProfile = profile;
        _maxHrController.text = profile.maxHr.toString();
        _ageController.text = profile.age?.toString() ?? '';
        _useAgeBased = profile.useAgeBased;
        _audioFeedbackEnabled = profile.audioFeedbackEnabled;
        _audioVolume = profile.audioVolume;
        _isLoading = false;
      });

      AudioFeedbackService.instance.isEnabled = profile.audioFeedbackEnabled;
      AudioFeedbackService.instance.volume = profile.audioVolume;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
        setState(() {
          _maxHrController.text = '180';
          _useAgeBased = false;
          _audioFeedbackEnabled = true;
          _audioVolume = 0.7;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final maxHr = int.parse(_maxHrController.text);
      final age = _ageController.text.isNotEmpty ? int.tryParse(_ageController.text) : null;

      final profile = UserProfile(
        maxHr: maxHr,
        age: age,
        useAgeBased: _useAgeBased,
        customZones: _currentProfile?.customZones,
        audioFeedbackEnabled: _audioFeedbackEnabled,
        audioVolume: _audioVolume,
      );

      await ProfileService.instance.saveProfile(profile);
      AudioFeedbackService.instance.isEnabled = _audioFeedbackEnabled;
      AudioFeedbackService.instance.volume = _audioVolume;

      if (mounted) {
        setState(() => _currentProfile = profile);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _validateMaxHr(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your maximum heart rate';
    final maxHr = int.tryParse(value);
    if (maxHr == null) return 'Please enter a valid number';
    if (maxHr < 100 || maxHr > 220) return 'Max heart rate must be between 100 and 220';
    return null;
  }

  String? _validateAge(String? value) {
    if (value == null || value.isEmpty) return null;
    final age = int.tryParse(value);
    if (age == null) return 'Please enter a valid number';
    if (age < 10 || age > 120) return 'Age must be between 10 and 120';
    return null;
  }

  int? get _effectiveMaxHr {
    if (_useAgeBased && _ageController.text.isNotEmpty) {
      final age = int.tryParse(_ageController.text);
      if (age != null) return UserProfile.calculateMaxHrFromAge(age);
    }
    return int.tryParse(_maxHrController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('settingsScreen'),
      appBar: AppBar(title: const Text('Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  ProfileSettingsCard(
                    ageController: _ageController,
                    maxHrController: _maxHrController,
                    useAgeBased: _useAgeBased,
                    effectiveMaxHr: _effectiveMaxHr,
                    onUseAgeBasedChanged: (v) => setState(() => _useAgeBased = v),
                    onValidateAge: _validateAge,
                    onValidateMaxHr: _validateMaxHr,
                  ),
                  const SizedBox(height: 16),
                  TrainingZonesCard(
                    effectiveMaxHr: _effectiveMaxHr,
                    zones: _currentProfile?.effectiveZones,
                  ),
                  const SizedBox(height: 16),
                  AudioSettingsCard(
                    audioFeedbackEnabled: _audioFeedbackEnabled,
                    audioVolume: _audioVolume,
                    onAudioFeedbackChanged: (v) => setState(() => _audioFeedbackEnabled = v),
                    onAudioVolumeChanged: (v) => setState(() => _audioVolume = v),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.favorite, color: Colors.red),
                      title: const Text('Health Settings'),
                      subtitle: const Text('Low heart rate alerts & quiet hours'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pushNamed(context, '/health-settings'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveProfile,
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
                  ),
                ],
              ),
            ),
    );
  }
}
