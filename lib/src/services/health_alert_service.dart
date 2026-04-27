import 'dart:async';

import 'package:heart_beat/src/bridge/api_generated.dart/api.dart' as generated;
import 'coaching_cue_service.dart';

/// Service that provides health-rule alerts (e.g. sustained low HR) to the UI
/// without coupling the screen to the coaching subsystem.
///
/// Shares the single [CoachingCueService.cueStream] subscription, filtering for
/// health-specific cues and exposing them via a dedicated [healthAlertStream].
class HealthAlertService {
  HealthAlertService._();

  static final HealthAlertService _instance = HealthAlertService._();

  static HealthAlertService get instance => _instance;

  /// Stream of health alerts. Currently only emits for [sustained_low_hr],
  /// but this interface allows future health rules to be added without
  /// coupling additional coaching logic to the UI.
  Stream<generated.ApiCue> get healthAlertStream =>
      CoachingCueService.instance.cueStream.where(
            (cue) => cue.label == 'sustained_low_hr',
          );
}