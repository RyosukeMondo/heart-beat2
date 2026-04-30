import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';
import '../services/audio_feedback_service.dart';
import '../widgets/profile_settings_card.dart';
import '../widgets/audio_settings_card.dart';
import '../widgets/training_zones_card.dart';

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
                    onPlayTestSound: () => AudioFeedbackService.instance.playZoneTooHigh(),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.favorite, color: Colors.red),
                      title: const Text('Health'),
                      subtitle: const Text('View averages, sparkline & rule status'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pushNamed(context, '/health'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.favorite_border, color: Colors.red),
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
