import 'package:flutter/material.dart';
import '../bridge/api_generated.dart/api.dart';

/// Banner widget that displays BLE connection status.
///
/// Shows reconnection progress, connection failures, and other connection
/// state changes to keep users informed during workouts.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ApiConnectionStatus>(
      stream: createConnectionStatusStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final status = snapshot.data!;
        return FutureBuilder<_BannerData?>(
          future: _getBannerData(status),
          builder: (context, dataSnapshot) {
            if (!dataSnapshot.hasData || dataSnapshot.data == null) {
              return const SizedBox.shrink();
            }

            final data = dataSnapshot.data!;
            return MaterialBanner(
              backgroundColor: data.backgroundColor,
              leading: data.icon,
              content: Text(
                data.message,
                style: TextStyle(
                  color: data.textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              actions: data.actions,
            );
          },
        );
      },
    );
  }

  /// Extract banner data from connection status.
  Future<_BannerData?> _getBannerData(ApiConnectionStatus status) async {
    final isReconnecting = await connectionStatusIsReconnecting(status: status);
    if (isReconnecting) {
      final attempt = await connectionStatusAttempt(status: status);
      final maxAttempts = await connectionStatusMaxAttempts(status: status);
      return _BannerData(
        message: 'Reconnecting... (attempt $attempt/$maxAttempts)',
        backgroundColor: Colors.orange.shade100,
        textColor: Colors.orange.shade900,
        icon: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade900),
          ),
        ),
        actions: [const SizedBox.shrink()],
      );
    }

    final isFailed = await connectionStatusIsReconnectFailed(status: status);
    if (isFailed) {
      final reason = await connectionStatusFailureReason(status: status);
      return _BannerData(
        message: 'Connection lost: ${reason ?? "Unknown error"}',
        backgroundColor: Colors.red.shade100,
        textColor: Colors.red.shade900,
        icon: Icon(Icons.warning, color: Colors.red.shade900),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Implement manual retry when reconnect API is added
            },
            child: Text(
              'Retry',
              style: TextStyle(color: Colors.red.shade900),
            ),
          ),
        ],
      );
    }

    final isDisconnected = await connectionStatusIsDisconnected(status: status);
    if (isDisconnected) {
      return _BannerData(
        message: 'Device disconnected',
        backgroundColor: Colors.grey.shade200,
        textColor: Colors.grey.shade900,
        icon: Icon(Icons.bluetooth_disabled, color: Colors.grey.shade900),
        actions: [const SizedBox.shrink()],
      );
    }

    // Don't show banner for Connecting or Connected states
    return null;
  }
}

/// Internal data class for banner styling.
class _BannerData {
  final String message;
  final Color backgroundColor;
  final Color textColor;
  final Widget icon;
  final List<Widget> actions;

  _BannerData({
    required this.message,
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
    required this.actions,
  });
}
