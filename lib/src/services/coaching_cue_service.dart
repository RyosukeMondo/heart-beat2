import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/frb_generated.dart';
import 'package:heart_beat/src/services/health_settings_service.dart';
import 'voice_coaching_service.dart';

/// Global navigator key for deep-links from notifications when no context
/// is available (e.g., cold-start from notification tap).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Service that consumes coaching cues from the Rust rule engine and
/// delivers them via multiple surfaces: in-app toast, local notification,
/// and optional TTS.
///
/// Implements the delivery portion of task 5.4:
/// "Rust: create_coaching_cue_stream() -> Stream<Cue> via frb.
///  Dart side consumer routes each cue to:
///  - In-app: toast/snackbar + optional animated banner on the coaching screen.
///  - Local notification: flutter_local_notifications package.
///  - TTS (optional, opt-in): flutter_tts speaks the cue aloud.
///  User preference toggles: enable notifications, enable TTS, choose voice."
class CoachingCueService {
  CoachingCueService._();

  static final CoachingCueService _instance = CoachingCueService._();

  static CoachingCueService get instance => _instance;

  // ---------------------------------------------------------------------------
  // Preferences keys
  // ---------------------------------------------------------------------------

  static const _prefNotificationsEnabled = 'coaching_notifications_enabled';
  static const _prefInAppToastEnabled = 'coaching_inapp_toast_enabled';

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// User preference: show local notifications when backgrounded.
  bool _notificationsEnabled = true;

  /// User preference: show in-app toast/banner.
  bool _inAppToastEnabled = true;

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  bool get notificationsEnabled => _notificationsEnabled;
  bool get ttsEnabled => VoiceCoachingService.instance.isEnabled;
  bool get inAppToastEnabled => _inAppToastEnabled;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initialize the notification plugin and load user preferences.
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Load user preferences
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool(_prefNotificationsEnabled) ?? true;
    _inAppToastEnabled = prefs.getBool(_prefInAppToastEnabled) ?? true;

    _isInitialized = true;

    if (kDebugMode) {
      debugPrint('CoachingCueService initialized');
    }
  }

  /// Initialize the TTS engine (called from app startup).
  Future<void> initializeTts() async {
    await VoiceCoachingService.instance.initialize();
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint('Coaching notification tapped: ${response.payload}');
    }
    // Handle deep-link: notification tap opens the Health screen.
    if (response.payload == 'sustained_low_hr') {
      _openHealthScreen();
    }
  }

  void _openHealthScreen() {
    // Navigation is handled via the global navigator; a simple push works
    // whether the app is cold-started or already running.
    // Use a post-frame callback so the navigator is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (kDebugMode) {
        debugPrint('Opening Health screen from notification tap');
      }
      // The route '/health' is registered in app.dart.
      // We use Navigator state from the current context if available,
      // otherwise fall back to the global navigator.
      navigatorKey.currentState?.pushNamed('/health');
    });
  }

  // ---------------------------------------------------------------------------
  // Preference setters
  // ---------------------------------------------------------------------------

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefNotificationsEnabled, value);
    if (kDebugMode) {
      debugPrint('Coaching notifications enabled: $value');
    }
  }

  Future<void> setTtsEnabled(bool value) async {
    await VoiceCoachingService.instance.setEnabled(value);
    if (kDebugMode) {
      debugPrint('Coaching TTS enabled: $value');
    }
  }

  Future<void> setInAppToastEnabled(bool value) async {
    _inAppToastEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefInAppToastEnabled, value);
    if (kDebugMode) {
      debugPrint('Coaching in-app toast enabled: $value');
    }
  }

  // ---------------------------------------------------------------------------
  // Stream consumption
  // ---------------------------------------------------------------------------

  StreamSubscription<ApiCue>? _cueSubscription;

  /// Start listening to coaching cues from the Rust rule engine.
  Stream<ApiCue> createCueStream() {
    return RustLib.instance.api.crateApiCreateCoachingCueStream();
  }

  /// Start listening to the cue stream and dispatch each cue to the appropriate
  /// surface (toast, notification, TTS). Call this once at app startup.
  void startCueListener() {
    _cueSubscription?.cancel();
    _cueSubscription = createCueStream().listen((cue) => onCue(cue));
    if (kDebugMode) {
      debugPrint('CoachingCueService: cue listener started');
    }
  }

  /// Process a single cue — dispatch to toast, notification, and TTS
  /// based on user preferences and cue priority.
  Future<void> onCue(ApiCue cue) async {
    if (kDebugMode) {
      debugPrint('CoachingCueService received cue: ${cue.label} - ${cue.message}');
    }

    // Handle sustained_low_hr with custom notification formatting and
    // master-toggle-gated notification delivery.
    if (cue.label == 'sustained_low_hr') {
      await _handleSustainedLowHrCue(cue);
      return;
    }

    // In-app toast (Normal+ priority cues only)
    if (_inAppToastEnabled && cue.priority >= 1) {
      await _showInAppToast(cue);
    }

    // TTS for High/Critical priority cues
    if (VoiceCoachingService.instance.isEnabled && cue.priority >= 2) {
      await _speakCue(cue);
    }

    // Local notification for High/Critical priority when backgrounded
    if (_notificationsEnabled && cue.priority >= 2) {
      await _showNotification(cue);
    }
  }

  /// Handle the sustained_low_hr cue: show a custom notification only when
  /// the health-notifications master toggle is enabled.
  Future<void> _handleSustainedLowHrCue(ApiCue cue) async {
    // Only show notification if master notifications toggle is on.
    if (!HealthSettingsService.instance.notificationsEnabled) {
      if (kDebugMode) {
        debugPrint('sustained_low_hr suppressed: notifications disabled');
      }
      return;
    }

    await _showSustainedLowHrNotification(cue);
  }

  /// Show the custom low-HR notification with the exact format required:
  /// title = 'Heart rate low', body = 'Average HR was {avg_bpm} bpm over
  /// the last {window_min} min', tap opens the Health screen.
  Future<void> _showSustainedLowHrNotification(ApiCue cue) async {
    const androidDetails = AndroidNotificationDetails(
      'health_alerts',
      'Health Alerts',
      channelDescription: 'Low heart rate health alerts',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Parse avg_bpm and window_min from the cue message.
    // Message format: "Heart rate low — average {avg_bpm} bpm over the last {:.0} min"
    final avgBpm = _parseAvgBpm(cue.message);
    final windowMin = _parseWindowMin(cue.message);

    const title = 'Heart rate low';
    final body = 'Average HR was $avgBpm bpm over the last $windowMin min';

    await _notifications.show(
      cue.hashCode,
      title,
      body,
      details,
      payload: 'sustained_low_hr',
    );
  }

  int _parseAvgBpm(String message) {
    // Extract "average N bpm" from the message.
    final match = RegExp(r'average (\d+) bpm').firstMatch(message);
    return int.tryParse(match?.group(1) ?? '0') ?? 0;
  }

  int _parseWindowMin(String message) {
    // Extract "last N min" from the message.
    final match = RegExp(r'last ([\d.]+) min').firstMatch(message);
    if (match == null) return 0;
    return double.parse(match.group(1)!).round();
  }

  // ---------------------------------------------------------------------------
  // Delivery surfaces
  // ---------------------------------------------------------------------------

  /// In-app toast (implemented as debugPrint for now; UI integration
  /// via CoachingScreen will call onCue and display a banner).
  Future<void> _showInAppToast(ApiCue cue) async {
    // The actual toast/banner rendering is done by the UI layer that
    // consumes the stream. This method can be extended to use a
    // global Snackbar or overlay. For now, log it.
    if (kDebugMode) {
      debugPrint('[Coaching Toast] ${cue.message}');
    }
  }

  Future<void> _showNotification(ApiCue cue) async {
    const androidDetails = AndroidNotificationDetails(
      'coaching_cues',
      'Coaching Cues',
      channelDescription: 'Heart rate coaching prompts',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = _notificationTitle(cue.label);
    await _notifications.show(
      cue.hashCode,
      title,
      cue.message,
      details,
      payload: cue.id,
    );
  }

  String _notificationTitle(String label) {
    switch (label) {
      case 'raise_hr':
        return 'Raise Heart Rate';
      case 'cool_down':
        return 'Cool Down';
      case 'stand_up':
        return 'Stand Up';
      case 'ease_off':
        return 'Ease Off';
      default:
        return 'Coaching';
    }
  }

  Future<void> _speakCue(ApiCue cue) async {
    // Strip any ANSI / formatting from the message before speaking
    final text = cue.message.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    await VoiceCoachingService.instance.speak(text);
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  Future<void> dispose() async {
    await _notifications.cancelAll();
    await VoiceCoachingService.instance.dispose();
    _isInitialized = false;
    if (kDebugMode) {
      debugPrint('CoachingCueService disposed');
    }
  }
}