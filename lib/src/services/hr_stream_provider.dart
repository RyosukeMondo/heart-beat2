import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';

export 'package:heart_beat/src/bridge/api_generated.dart/api.dart' show ApiFilteredHeartRate, hrFilteredBpm;

/// Provides access to the filtered heart rate stream from Rust.
///
/// Exists to break the API boundary, allowing services like
/// [CoachingScreenStreams] to consume the HR stream without
/// importing the API generated code directly.
Stream<ApiFilteredHeartRate> get hrStream => createHrStream();