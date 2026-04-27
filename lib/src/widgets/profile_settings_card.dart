import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
            _buildTitle(context),
            const SizedBox(height: 16),
            _buildAgeField(),
            const SizedBox(height: 16),
            _buildUseAgeBasedSwitch(context),
            const SizedBox(height: 16),
            _buildMaxHrField(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Text(
      'Heart Rate Configuration',
      style: Theme.of(context).textTheme.titleLarge,
    );
  }

  Widget _buildAgeField() {
    return TextFormField(
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
    );
  }

  Widget _buildUseAgeBasedSwitch(BuildContext context) {
    return SwitchListTile(
      key: const Key('useAgeBasedSwitch'),
      title: const Text('Use age-based max HR'),
      subtitle: useAgeBased && ageController.text.isNotEmpty
          ? Text('Estimated max HR: ${effectiveMaxHr ?? "--"} BPM')
          : const Text('Enable to use age-based calculation (220 - age)'),
      value: useAgeBased,
      onChanged: ageController.text.isNotEmpty ? onUseAgeBasedChanged : null,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildMaxHrField(BuildContext context) {
    return TextFormField(
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
    );
  }
}
