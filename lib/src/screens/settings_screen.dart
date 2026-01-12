import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

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

  /// Load profile from ProfileService
  Future<void> _loadProfile() async {
    try {
      final profile = await ProfileService.instance.getProfile();
      setState(() {
        _currentProfile = profile;
        _maxHrController.text = profile.maxHr.toString();
        _ageController.text = profile.age?.toString() ?? '';
        _useAgeBased = profile.useAgeBased;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
        setState(() {
          _maxHrController.text = '180';
          _useAgeBased = false;
          _isLoading = false;
        });
      }
    }
  }

  /// Save profile to ProfileService
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final maxHr = int.parse(_maxHrController.text);
      final age = _ageController.text.isNotEmpty
          ? int.tryParse(_ageController.text)
          : null;

      final profile = UserProfile(
        maxHr: maxHr,
        age: age,
        useAgeBased: _useAgeBased,
        customZones: _currentProfile?.customZones,
      );

      await ProfileService.instance.saveProfile(profile);

      if (mounted) {
        setState(() {
          _currentProfile = profile;
        });
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
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Validate max heart rate input
  String? _validateMaxHr(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your maximum heart rate';
    }

    final maxHr = int.tryParse(value);
    if (maxHr == null) {
      return 'Please enter a valid number';
    }

    if (maxHr < 100 || maxHr > 220) {
      return 'Max heart rate must be between 100 and 220';
    }

    return null;
  }

  /// Validate age input
  String? _validateAge(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Age is optional
    }

    final age = int.tryParse(value);
    if (age == null) {
      return 'Please enter a valid number';
    }

    if (age < 10 || age > 120) {
      return 'Age must be between 10 and 120';
    }

    return null;
  }

  /// Get the effective max HR based on current settings
  int? get _effectiveMaxHr {
    if (_useAgeBased && _ageController.text.isNotEmpty) {
      final age = int.tryParse(_ageController.text);
      if (age != null) {
        return UserProfile.calculateMaxHrFromAge(age);
      }
    }
    return int.tryParse(_maxHrController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('settingsScreen'),
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Card(
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
                          // Age input
                          TextFormField(
                            key: const Key('ageField'),
                            controller: _ageController,
                            decoration: const InputDecoration(
                              labelText: 'Age (optional)',
                              helperText: 'Used for age-based max HR estimation',
                              suffixText: 'years',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: _validateAge,
                            onChanged: (value) {
                              setState(() {}); // Rebuild to update estimated max HR
                            },
                          ),
                          const SizedBox(height: 16),
                          // Use age-based max HR toggle
                          SwitchListTile(
                            key: const Key('useAgeBasedSwitch'),
                            title: const Text('Use age-based max HR'),
                            subtitle: _useAgeBased && _ageController.text.isNotEmpty
                                ? Text('Estimated max HR: ${_effectiveMaxHr ?? "--"} BPM')
                                : const Text('Enable to use age-based calculation (220 - age)'),
                            value: _useAgeBased,
                            onChanged: _ageController.text.isNotEmpty
                                ? (value) {
                                    setState(() {
                                      _useAgeBased = value;
                                    });
                                  }
                                : null,
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 16),
                          // Manual max HR input (disabled when using age-based)
                          TextFormField(
                            key: const Key('maxHrField'),
                            controller: _maxHrController,
                            decoration: InputDecoration(
                              labelText: 'Maximum Heart Rate',
                              helperText: _useAgeBased
                                  ? 'Using age-based calculation'
                                  : 'Used to calculate training zones (100-220 BPM)',
                              suffixText: 'BPM',
                              border: const OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: _validateMaxHr,
                            enabled: !_useAgeBased,
                            onChanged: (value) {
                              setState(() {}); // Rebuild to update zones
                            },
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Training Zones',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          _buildZoneDisplay(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveProfile,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
                  ),
                ],
              ),
            ),
    );
  }

  /// Build the training zones display with BPM ranges
  Widget _buildZoneDisplay() {
    final effectiveMaxHr = _effectiveMaxHr;
    if (effectiveMaxHr == null) {
      return const Text('Enter max HR or age to see zone ranges');
    }

    final zones = _currentProfile?.effectiveZones ?? CustomZones.defaults;

    return Column(
      children: [
        _buildZoneInfo(
          'Zone 1 (Recovery)',
          '0-${zones.zone1Max}%',
          Colors.blue,
          0,
          zones.zone1Max,
          effectiveMaxHr,
        ),
        _buildZoneInfo(
          'Zone 2 (Fat Burning)',
          '${zones.zone1Max}-${zones.zone2Max}%',
          Colors.green,
          zones.zone1Max,
          zones.zone2Max,
          effectiveMaxHr,
        ),
        _buildZoneInfo(
          'Zone 3 (Aerobic)',
          '${zones.zone2Max}-${zones.zone3Max}%',
          Colors.yellow,
          zones.zone2Max,
          zones.zone3Max,
          effectiveMaxHr,
        ),
        _buildZoneInfo(
          'Zone 4 (Threshold)',
          '${zones.zone3Max}-${zones.zone4Max}%',
          Colors.orange,
          zones.zone3Max,
          zones.zone4Max,
          effectiveMaxHr,
        ),
        _buildZoneInfo(
          'Zone 5 (Maximum)',
          '${zones.zone4Max}-100%',
          Colors.red,
          zones.zone4Max,
          100,
          effectiveMaxHr,
        ),
      ],
    );
  }

  /// Build a training zone information row with BPM range
  Widget _buildZoneInfo(
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
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
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
