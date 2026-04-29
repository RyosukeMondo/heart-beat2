import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';

export 'package:heart_beat/src/bridge/api_generated.dart/api.dart' show ApiConnectionStatus, connectionStatusIsConnected;

/// Provides access to the connection status stream from Rust.
///
/// Exists to break the API boundary, allowing services like
/// [CoachingScreenStreams] to consume the connection status stream
/// without importing the API generated code directly.
Stream<ApiConnectionStatus> get connectionStatusStream => createConnectionStatusStream();