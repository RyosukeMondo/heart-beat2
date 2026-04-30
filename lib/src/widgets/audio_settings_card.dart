import 'package:flutter/material.dart';

class AudioSettingsCard extends StatelessWidget {
  final bool audioFeedbackEnabled;
  final double audioVolume;
  final ValueChanged<bool> onAudioFeedbackChanged;
  final ValueChanged<double> onAudioVolumeChanged;
  final VoidCallback? onPlayTestSound;

  const AudioSettingsCard({
    super.key,
    required this.audioFeedbackEnabled,
    required this.audioVolume,
    required this.onAudioFeedbackChanged,
    required this.onAudioVolumeChanged,
    this.onPlayTestSound,
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
                  onPressed: audioFeedbackEnabled ? onPlayTestSound : null,
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