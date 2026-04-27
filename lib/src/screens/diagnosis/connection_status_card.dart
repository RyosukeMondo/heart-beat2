import 'package:flutter/material.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';

class DiagnosisConnectionStatusCard extends StatelessWidget {
  const DiagnosisConnectionStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ApiConnectionStatus>(
      stream: createConnectionStatusStream(),
      builder: (context, snapshot) {
        final status = snapshot.data;
        final theme = Theme.of(context);

        return FutureBuilder<_CardData?>(
          future: _getCardData(status),
          builder: (context, dataSnapshot) {
            final data = dataSnapshot.data ?? _defaultCardData(status);
            return Container(
              padding: const EdgeInsets.all(12),
              color: theme.colorScheme.surfaceContainerHighest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(data.icon, size: 20, color: data.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data.label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (data.isConnected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Connected',
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (data.isConnecting)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (data.deviceId.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.device_unknown,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            data.deviceId,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (data.error.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      data.error,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.red,
                      ),
                    ),
                  ],
                  if (data.isReconnecting) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: data.reconnectProgress,
                              backgroundColor: Colors.orange.shade100,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.orange.shade700,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${data.attempt}/${data.maxAttempts}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<_CardData?> _getCardData(ApiConnectionStatus? status) async {
    if (status == null) return null;
    final isConn = await connectionStatusIsConnected(status: status);
    final isConning = await connectionStatusIsConnecting(status: status);
    final isRecon = await connectionStatusIsReconnecting(status: status);
    final isFailed = await connectionStatusIsReconnectFailed(status: status);

    if (isConn) {
      final deviceId = await connectionStatusDeviceId(status: status) ?? '';
      return _CardData(
        label: 'Device Connected',
        icon: Icons.bluetooth_connected,
        color: Colors.green,
        isConnected: true,
        isConnecting: false,
        isReconnecting: false,
        deviceId: deviceId,
        error: '',
        attempt: 0,
        maxAttempts: 1,
      );
    }

    if (isConning) {
      return _CardData(
        label: 'Connecting...',
        icon: Icons.bluetooth_searching,
        color: Colors.blue,
        isConnected: false,
        isConnecting: true,
        isReconnecting: false,
        deviceId: '',
        error: '',
        attempt: 0,
        maxAttempts: 1,
      );
    }

    if (isRecon) {
      final attempt = await connectionStatusAttempt(status: status) ?? 0;
      final maxAttempts = await connectionStatusMaxAttempts(status: status) ?? 1;
      return _CardData(
        label: 'Reconnecting...',
        icon: Icons.sync,
        color: Colors.orange,
        isConnected: false,
        isConnecting: false,
        isReconnecting: true,
        deviceId: '',
        error: '',
        attempt: attempt,
        maxAttempts: maxAttempts,
      );
    }

    if (isFailed) {
      final reason = await connectionStatusFailureReason(status: status) ?? 'Unknown error';
      return _CardData(
        label: 'Connection Failed',
        icon: Icons.error_outline,
        color: Colors.red,
        isConnected: false,
        isConnecting: false,
        isReconnecting: false,
        deviceId: '',
        error: reason,
        attempt: 0,
        maxAttempts: 1,
      );
    }

    return _CardData(
      label: 'Disconnected',
      icon: Icons.bluetooth_disabled,
      color: Colors.grey,
      isConnected: false,
      isConnecting: false,
      isReconnecting: false,
      deviceId: '',
      error: '',
      attempt: 0,
      maxAttempts: 1,
    );
  }

  _CardData _defaultCardData(ApiConnectionStatus? status) {
    return _CardData(
      label: 'Unknown',
      icon: Icons.bluetooth_disabled,
      color: Colors.grey,
      isConnected: false,
      isConnecting: false,
      isReconnecting: false,
      deviceId: '',
      error: '',
      attempt: 0,
      maxAttempts: 1,
    );
  }
}

class _CardData {
  final String label;
  final IconData icon;
  final Color color;
  final bool isConnected;
  final bool isConnecting;
  final bool isReconnecting;
  final String deviceId;
  final String error;
  final int attempt;
  final int maxAttempts;

  _CardData({
    required this.label,
    required this.icon,
    required this.color,
    required this.isConnected,
    required this.isConnecting,
    required this.isReconnecting,
    required this.deviceId,
    required this.error,
    required this.attempt,
    required this.maxAttempts,
  });

  double get reconnectProgress =>
      maxAttempts > 0 ? attempt / maxAttempts : 0;
}
