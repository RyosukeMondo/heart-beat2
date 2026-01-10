import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings screen for user configuration
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _maxHrController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadMaxHr();
  }

  @override
  void dispose() {
    _maxHrController.dispose();
    super.dispose();
  }

  /// Load max heart rate from SharedPreferences
  Future<void> _loadMaxHr() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final maxHr = prefs.getInt('max_hr') ?? 180;
      setState(() {
        _maxHrController.text = maxHr.toString();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
        setState(() {
          _maxHrController.text = '180';
          _isLoading = false;
        });
      }
    }
  }

  /// Save max heart rate to SharedPreferences
  Future<void> _saveMaxHr() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final maxHr = int.parse(_maxHrController.text);
      await prefs.setInt('max_hr', maxHr);

      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                          TextFormField(
                            controller: _maxHrController,
                            decoration: const InputDecoration(
                              labelText: 'Maximum Heart Rate',
                              helperText: 'Used to calculate training zones (100-220 BPM)',
                              suffixText: 'BPM',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: _validateMaxHr,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Training Zones',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          _buildZoneInfo(
                            'Zone 1 (Recovery)',
                            '50-60%',
                            Colors.blue,
                          ),
                          _buildZoneInfo(
                            'Zone 2 (Fat Burning)',
                            '60-70%',
                            Colors.green,
                          ),
                          _buildZoneInfo(
                            'Zone 3 (Aerobic)',
                            '70-80%',
                            Colors.yellow,
                          ),
                          _buildZoneInfo(
                            'Zone 4 (Threshold)',
                            '80-90%',
                            Colors.orange,
                          ),
                          _buildZoneInfo(
                            'Zone 5 (Maximum)',
                            '90-100%',
                            Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _saveMaxHr,
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

  /// Build a training zone information row
  Widget _buildZoneInfo(String name, String percentage, Color color) {
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
            percentage,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
