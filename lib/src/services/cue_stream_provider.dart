import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/frb_generated.dart';

/// Callback type for handling sustained low HR coaching cues.
typedef SustainedLowHrHandler = void Function(ApiCue cue);

/// Provides access to the coaching cue stream from the Rust rule engine.
///
/// Exists to break the cyclic import between [CoachingCueService] and
/// [HealthAlertService].
Stream<ApiCue> get cueStream =>
    RustLib.instance.api.crateApiCreateCoachingCueStream();