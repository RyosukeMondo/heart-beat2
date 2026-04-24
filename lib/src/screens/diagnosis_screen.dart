import 'package:flutter/material.dart';

/// Diagnosis screen — a debug/dev surface showing live device state,
/// log viewer, and operations panel.
/// Gated on kDebugMode; production users cannot stumble into it.
class DiagnosisScreen extends StatelessWidget {
  const DiagnosisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('diagnosisScreen'),
      appBar: AppBar(
        title: const Text('Diagnosis'),
      ),
      body: const Center(
        child: Text('Diagnosis skeleton — task 3.1'),
      ),
    );
  }
}