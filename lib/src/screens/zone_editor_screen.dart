import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

/// Screen for editing custom training zone thresholds
class ZoneEditorScreen extends StatefulWidget {
  const ZoneEditorScreen({super.key});

  @override
  State<ZoneEditorScreen> createState() => _ZoneEditorScreenState();
}

class _ZoneEditorScreenState extends State<ZoneEditorScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  UserProfile? _currentProfile;

  // Zone boundaries as percentages (0-100)
  double _zone1Max = 60;
  double _zone2Max = 70;
  double _zone3Max = 80;
  double _zone4Max = 90;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Load profile and initialize zone values
  Future<void> _loadProfile() async {
    try {
      final profile = await ProfileService.instance.getProfile();
      setState(() {
        _currentProfile = profile;
        final zones = profile.effectiveZones;
        _zone1Max = zones.zone1Max.toDouble();
        _zone2Max = zones.zone2Max.toDouble();
        _zone3Max = zones.zone3Max.toDouble();
        _zone4Max = zones.zone4Max.toDouble();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Save custom zones to profile
  Future<void> _saveZones() async {
    if (_currentProfile == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final customZones = CustomZones(
        zone1Max: _zone1Max.round(),
        zone2Max: _zone2Max.round(),
        zone3Max: _zone3Max.round(),
        zone4Max: _zone4Max.round(),
      );

      final updatedProfile = UserProfile(
        maxHr: _currentProfile!.maxHr,
        age: _currentProfile!.age,
        useAgeBased: _currentProfile!.useAgeBased,
        customZones: customZones,
      );

      await ProfileService.instance.saveProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Custom zones saved successfully')),
        );
        Navigator.of(context).pop(true); // Return true to indicate changes were saved
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving zones: $e')),
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

  /// Reset zones to defaults
  void _resetToDefaults() {
    setState(() {
      _zone1Max = CustomZones.defaults.zone1Max.toDouble();
      _zone2Max = CustomZones.defaults.zone2Max.toDouble();
      _zone3Max = CustomZones.defaults.zone3Max.toDouble();
      _zone4Max = CustomZones.defaults.zone4Max.toDouble();
    });
  }

  /// Validate that zones are in ascending order
  bool get _zonesValid {
    return _zone1Max < _zone2Max &&
        _zone2Max < _zone3Max &&
        _zone3Max < _zone4Max &&
        _zone4Max < 100;
  }

  /// Get validation error message
  String? get _validationError {
    if (!_zonesValid) {
      return 'Zone boundaries must be in ascending order and less than 100%';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Training Zones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetToDefaults,
            tooltip: 'Reset to defaults',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zone Boundaries',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Adjust the upper boundary for each zone as a percentage of your max heart rate.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (_validationError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _validationError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          _buildZoneSlider(
                            'Zone 1 (Recovery)',
                            Colors.blue,
                            0,
                            _zone1Max,
                            (value) {
                              setState(() {
                                _zone1Max = value;
                              });
                            },
                          ),
                          _buildZoneSlider(
                            'Zone 2 (Fat Burning)',
                            Colors.green,
                            _zone1Max,
                            _zone2Max,
                            (value) {
                              setState(() {
                                _zone2Max = value;
                              });
                            },
                          ),
                          _buildZoneSlider(
                            'Zone 3 (Aerobic)',
                            Colors.yellow,
                            _zone2Max,
                            _zone3Max,
                            (value) {
                              setState(() {
                                _zone3Max = value;
                              });
                            },
                          ),
                          _buildZoneSlider(
                            'Zone 4 (Threshold)',
                            Colors.orange,
                            _zone3Max,
                            _zone4Max,
                            (value) {
                              setState(() {
                                _zone4Max = value;
                              });
                            },
                          ),
                          _buildZoneFinalInfo('Zone 5 (Maximum)', Colors.red, _zone4Max, 100),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zone Preview',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          _buildZonePreview(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: (_isSaving || !_zonesValid) ? null : _saveZones,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Saving...' : 'Save Custom Zones'),
                  ),
                ],
              ),
            ),
    );
  }

  /// Build a zone slider control
  Widget _buildZoneSlider(
    String name,
    Color color,
    double minValue,
    double currentValue,
    ValueChanged<double> onChanged,
  ) {
    final maxHr = _currentProfile?.effectiveMaxHr ?? 180;
    final minBpm = (maxHr * minValue / 100).round();
    final maxBpm = (maxHr * currentValue / 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '${currentValue.round()}% ($minBpm-$maxBpm BPM)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            value: currentValue,
            min: minValue + 1,
            max: 99,
            divisions: 98 - minValue.round(),
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }

  /// Build info for the final zone (no slider)
  Widget _buildZoneFinalInfo(String name, Color color, double minValue, double maxValue) {
    final maxHr = _currentProfile?.effectiveMaxHr ?? 180;
    final minBpm = (maxHr * minValue / 100).round();
    final maxBpm = (maxHr * maxValue / 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
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
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            '${minValue.round()}-${maxValue.round()}% ($minBpm-$maxBpm BPM)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Build visual preview of zones as stacked bars
  Widget _buildZonePreview() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: _zone1Max.round(),
              child: Container(
                height: 40,
                color: Colors.blue,
                alignment: Alignment.center,
                child: _zone1Max > 10
                    ? const Text(
                        'Z1',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
            Expanded(
              flex: (_zone2Max - _zone1Max).round(),
              child: Container(
                height: 40,
                color: Colors.green,
                alignment: Alignment.center,
                child: (_zone2Max - _zone1Max) > 10
                    ? const Text(
                        'Z2',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
            Expanded(
              flex: (_zone3Max - _zone2Max).round(),
              child: Container(
                height: 40,
                color: Colors.yellow,
                alignment: Alignment.center,
                child: (_zone3Max - _zone2Max) > 10
                    ? const Text(
                        'Z3',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
            Expanded(
              flex: (_zone4Max - _zone3Max).round(),
              child: Container(
                height: 40,
                color: Colors.orange,
                alignment: Alignment.center,
                child: (_zone4Max - _zone3Max) > 10
                    ? const Text(
                        'Z4',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
            Expanded(
              flex: (100 - _zone4Max).round(),
              child: Container(
                height: 40,
                color: Colors.red,
                alignment: Alignment.center,
                child: (100 - _zone4Max) > 10
                    ? const Text(
                        'Z5',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('0%', style: TextStyle(fontSize: 12)),
            Text('${_zone1Max.round()}%', style: const TextStyle(fontSize: 12)),
            Text('${_zone2Max.round()}%', style: const TextStyle(fontSize: 12)),
            Text('${_zone3Max.round()}%', style: const TextStyle(fontSize: 12)),
            Text('${_zone4Max.round()}%', style: const TextStyle(fontSize: 12)),
            const Text('100%', style: TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
