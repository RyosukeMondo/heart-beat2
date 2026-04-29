import 'package:flutter/foundation.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'package:heart_beat/src/services/connection_status_stream_provider.dart';

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
  ConnectionStatusServiceProvider._() {
    _initStreamSubscription();
  }

  static final ConnectionStatusServiceProvider _instance =
      ConnectionStatusServiceProvider._();

  static ConnectionStatusServiceProvider get instance => _instance;

  ApiConnectionStatus? _latestStatus;

  void _initStreamSubscription() {
    connectionStatusStream.listen((status) {
      _latestStatus = status;
    });
  }

  /// Extract all status data from the latest known connection status.
  ///
  /// Uses cached status from the connection status stream subscription,
  /// avoiding the need for callers to pass FFI boundary types.
  Future<ConnectionStatusData> getStatusData() async {
    final status = _latestStatus;
    if (status == null) {
      return const ConnectionStatusData(
        isConnected: false,
        isConnecting: false,
        isReconnecting: false,
        isReconnectFailed: false,
        isDisconnected: true,
      );
    }

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