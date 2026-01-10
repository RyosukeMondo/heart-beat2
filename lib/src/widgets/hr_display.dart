import 'package:flutter/material.dart';

/// Widget displaying heart rate BPM in large, centered text.
///
/// This is a stateless widget designed for modularity and reusability
/// across the application where heart rate display is needed.
class HrDisplay extends StatelessWidget {
  /// The heart rate in beats per minute.
  final int bpm;

  const HrDisplay({
    super.key,
    required this.bpm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$bpm',
          style: const TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.bold,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const Text(
          'BPM',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}
