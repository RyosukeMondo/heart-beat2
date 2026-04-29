import 'package:flutter/foundation.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';

/// Data extracted from an [ApiConnectionStatus].
class ConnectionStatusData {
  final bool isConnected;
  final bool isConnecting;
  final bool isReconnecting;
  final bool isReconnectFailed;
  final bool isDisconnected;
  final String? deviceId;
  final int? attempt;
  final int? maxAttempts;
  final String? failureReason;

  const ConnectionStatusData({
    required this.isConnected,
    required this.isConnecting,
    required this.isReconnecting,
    required this.isReconnectFailed,
    required this.isDisconnected,
    this.deviceId,
    this.attempt,
    this.maxAttempts,
    this.failureReason,
  });
}

/// ChangeNotifier wrapper for ConnectionStatusService enabling DI via Provider.
///
/// This wraps the ConnectionStatusService singleton to expose it through the
/// widget tree using Provider pattern, satisfying the clean architecture
/// boundary requirement that UI layer should receive services via DI.
class ConnectionStatusServiceProvider extends ChangeNotifier {
  ConnectionStatusServiceProvider._();

  static final ConnectionStatusServiceProvider _instance =
      ConnectionStatusServiceProvider._();

  static ConnectionStatusServiceProvider get instance => _instance;

  /// Extract all status data from an [ApiConnectionStatus] in a single call.
  ///
  /// This is more efficient than making multiple FFI calls when all data is needed.
  Future<ConnectionStatusData> getStatusData(ApiConnectionStatus status) async {
    final isConn = await connectionStatusIsConnected(status: status);
    final isConning = await connectionStatusIsConnecting(status: status);
    final isRecon = await connectionStatusIsReconnecting(status: status);
    final isFailed = await connectionStatusIsReconnectFailed(status: status);
    final isDisconn = await connectionStatusIsDisconnected(status: status);

    String? deviceId;
    int? attempt;
    int? maxAttempts;
    String? failureReason;

    if (isConn) {
      deviceId = await connectionStatusDeviceId(status: status);
    }

    if (isRecon) {
      attempt = await connectionStatusAttempt(status: status);
      maxAttempts = await connectionStatusMaxAttempts(status: status);
    }

    if (isFailed) {
      failureReason = await connectionStatusFailureReason(status: status);
    }

    return ConnectionStatusData(
      isConnected: isConn,
      isConnecting: isConning,
      isReconnecting: isRecon,
      isReconnectFailed: isFailed,
      isDisconnected: isDisconn,
      deviceId: deviceId,
      attempt: attempt,
      maxAttempts: maxAttempts,
      failureReason: failureReason,
    );
  }
}

/// @deprecated Use [ConnectionStatusServiceProvider] instead.
/// Service that abstracts FFI connection status calls behind a clean API.
///
/// Breaks the API boundary so screens never call FFI functions directly.
class ConnectionStatusService {
  ConnectionStatusService._();

  static final ConnectionStatusService _instance = ConnectionStatusService._();
  static ConnectionStatusService get instance => _instance;

  /// Extract all status data from an [ApiConnectionStatus] in a single call.
  ///
  /// This is more efficient than making multiple FFI calls when all data is needed.
  Future<ConnectionStatusData> getStatusData(ApiConnectionStatus status) async {
    final isConn = await connectionStatusIsConnected(status: status);
    final isConning = await connectionStatusIsConnecting(status: status);
    final isRecon = await connectionStatusIsReconnecting(status: status);
    final isFailed = await connectionStatusIsReconnectFailed(status: status);
    final isDisconn = await connectionStatusIsDisconnected(status: status);

    String? deviceId;
    int? attempt;
    int? maxAttempts;
    String? failureReason;

    if (isConn) {
      deviceId = await connectionStatusDeviceId(status: status);
    }

    if (isRecon) {
      attempt = await connectionStatusAttempt(status: status);
      maxAttempts = await connectionStatusMaxAttempts(status: status);
    }

    if (isFailed) {
      failureReason = await connectionStatusFailureReason(status: status);
    }

    return ConnectionStatusData(
      isConnected: isConn,
      isConnecting: isConning,
      isReconnecting: isRecon,
      isReconnectFailed: isFailed,
      isDisconnected: isDisconn,
      deviceId: deviceId,
      attempt: attempt,
      maxAttempts: maxAttempts,
      failureReason: failureReason,
    );
  }
}