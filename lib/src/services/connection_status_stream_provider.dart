import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/frb_generated.dart';

/// Provides access to the connection status stream from Rust.
///
/// Exists to break the API boundary, allowing services like
/// [CoachingScreenStreams] to consume the connection status stream
/// without importing the API generated code directly.
Stream<ApiConnectionStatus> get connectionStatusStream =>
    RustLib.instance.api.crateApiCreateConnectionStatusStream();