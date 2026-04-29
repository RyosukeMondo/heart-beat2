import 'package:flutter/foundation.dart';

/// UI state for [SessionScreen].
///
/// Only manages background service state and UI callback — HR processing and
/// latency tracking are handled directly by [SessionScreen] via injected services.
class SessionScreenState {
  bool _isServiceRunning = false;
  VoidCallback? _onStateChange;

  bool get isServiceRunning => _isServiceRunning;

  void setOnStateChange(VoidCallback callback) {
    _onStateChange = callback;
  }

  void setServiceRunning(bool running) {
    _isServiceRunning = running;
    _onStateChange?.call();
  }

  void notifyStateChange() {
    _onStateChange?.call();
  }
}