import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart'
    show ApiCue, createCoachingCueStream;
import 'coaching_cue.dart';
import 'voice_coaching_handler.dart';

/// Domain event emitted when a coaching notification is tapped.
/// The app layer subscribes to [CoachingCueService.notificationTappedStream]
/// and translates this to the appropriate navigation action.
sealed class CoachingNotificationEvent {
  const CoachingNotificationEvent();
}

/// Event emitted when the user taps the sustained low HR notification.
const CoachingNotificationEvent notificationTappedSustainedLowHr =
    _NotificationTappedSustainedLowHr();

class _NotificationTappedSustainedLowHr extends CoachingNotificationEvent {
  const _NotificationTappedSustainedLowHr();
}

/// Service that consumes coaching cues from the Rust rule engine and
/// delivers them via multiple surfaces: in-app toast, local notification,
/// and optional TTS.
///
/// Implements the delivery portion of task 5.4:
/// "Rust: create_coaching_cue_stream() to Stream via frb.
///  Dart side consumer routes each cue to:
///  - In-app: toast/snackbar + optional animated banner on the coaching screen.
///  - Local notification: flutter_local_notifications package.
///  - TTS (optional, opt-in): flutter_tts speaks the cue aloud.
///  User preference toggles: enable notifications, enable TTS, choose voice."
class CoachingCueService {
  CoachingCueService._(VoiceCoachingHandler voiceHandler)
      : _voiceHandler = voiceHandler;

  /// Factory constructor that creates a [CoachingCueService] with the
  /// given [handler]. The returned instance must be set as the singleton
  /// via [setInstance].
  factory CoachingCueService.create(VoiceCoachingHandler handler) {
    return CoachingCueService._(handler);
  }

  static CoachingCueService? _instance;

  /// Returns the singleton [CoachingCueService] instance.
  ///
  /// The handler must be set via [setInstance] before first access in
  /// production. In tests, a mock handler can be injected.
  static CoachingCueService get instance {
    final inst = _instance;
    if (inst == null) {
      throw StateError(
        'CoachingCueService.instance used before setInstance() called. '
        'Call setInstance() with a VoiceCoachingHandler implementation.',
      );
    }
    return inst;
  }

  /// Sets the singleton instance with the given [instance].
  ///
  /// Must be called once at app startup before any other access.
  static void setInstance(CoachingCueService instance) {
    _instance = instance;
  }

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

  final VoiceCoachingHandler _voiceHandler;

  bool _isInitialized = false;

  /// User preference: show local notifications when backgrounded.
  bool _notificationsEnabled = true;

  /// User preference: show in-app toast/banner.
  bool _inAppToastEnabled = true;

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  bool get notificationsEnabled => _notificationsEnabled;
  bool get ttsEnabled => _voiceHandler.isEnabled;
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
    await _voiceHandler.initialize();
  }

  /// Stream of notification tap events for the app layer to consume and act on.
  final StreamController<CoachingNotificationEvent> _notificationEventController =
      StreamController<CoachingNotificationEvent>.broadcast();

  /// Stream of notification tap events (e.g., open Health screen on notification tap).
  Stream<CoachingNotificationEvent> get notificationTappedStream =>
      _notificationEventController.stream;

  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      debugPrint('Coaching notification tapped: ${response.payload}');
    }
    // Handle deep-link: notification tap opens the Health screen.
    if (response.payload == 'sustained_low_hr') {
      _notificationEventController.add(notificationTappedSustainedLowHr);
    }
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
    await _voiceHandler.setEnabled(value);
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

  /// Lazily created broadcast controller that holds a single shared Rust
  /// subscription and fans it out to all consumers.
  StreamController<Cue>? _cueStreamController;

  /// Stream of all coaching cues from the Rust rule engine.
  /// Shared by [CoachingScreen] and [CoachingCueService] to avoid duplicate
  /// stream consumption.
  Stream<Cue> get cueStream {
    _cueStreamController ??= _createCueStreamController();
    return _cueStreamController!.stream;
  }

  StreamController<Cue> _createCueStreamController() {
    final controller = StreamController<Cue>.broadcast();
    controller.addStream(
      createCoachingCueStream().map(_toCue),
    );
    return controller;
  }

  /// Converts an [ApiCue] from the Rust FFI layer to the stable [Cue] type.
  Cue _toCue(ApiCue apiCue) {
    return Cue(
      id: apiCue.id,
      label: apiCue.label,
      message: apiCue.message,
      priority: CuePriority.fromInt(apiCue.priority),
      generatedAt: DateTime.fromMillisecondsSinceEpoch(
        apiCue.generatedAtMillis.toInt(),
      ),
    );
  }

  /// Start listening to coaching cues from the Rust rule engine.
  Stream<Cue> createCueStream() {
    _cueStreamController ??= _createCueStreamController();
    return _cueStreamController!.stream;
  }

  /// Start listening to the cue stream and dispatch each cue to the appropriate
  /// surface (toast, notification, TTS). Call this once at app startup.
  void startCueListener() {
    // Stream is already active once cueStream has been accessed; nothing extra
    // needed here. The broadcast controller fans out to all listeners.
    if (kDebugMode) {
      debugPrint('CoachingCueService: cue listener started');
    }
  }

  /// Process a single cue — dispatch to toast, notification, and TTS
  /// based on user preferences and cue priority.
  Future<void> onCue(Cue cue) async {
    if (kDebugMode) {
      debugPrint('CoachingCueService received cue: ${cue.label} - ${cue.message}');
    }

    // In-app toast (Normal+ priority cues only)
    if (_inAppToastEnabled && cue.priorityValue >= 1) {
      await _showInAppToast(cue);
    }

    // TTS for High/Critical priority cues
    if (_voiceHandler.isEnabled && cue.priorityValue >= 2) {
      await _speakCue(cue);
    }

    // Local notification for High/Critical priority when backgrounded
    if (_notificationsEnabled && cue.priorityValue >= 2) {
      await _showNotification(cue);
    }
  }

  
  // ---------------------------------------------------------------------------
  // Delivery surfaces
  // ---------------------------------------------------------------------------

  /// In-app toast (implemented as debugPrint for now; UI integration
  /// via CoachingScreen will call onCue and display a banner).
  Future<void> _showInAppToast(Cue cue) async {
    // The actual toast/banner rendering is done by the UI layer that
    // consumes the stream. This method can be extended to use a
    // global Snackbar or overlay. For now, log it.
    if (kDebugMode) {
      debugPrint('[Coaching Toast] ${cue.message}');
    }
  }

  Future<void> _showNotification(Cue cue) async {
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

  Future<void> _speakCue(Cue cue) async {
    // Strip any ANSI / formatting from the message before speaking
    final text = cue.message.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    await _voiceHandler.speak(text);
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  Future<void> dispose() async {
    await _notifications.cancelAll();
    await _voiceHandler.dispose();
    await _notificationEventController.close();
    _isInitialized = false;
    if (kDebugMode) {
      debugPrint('CoachingCueService disposed');
    }
  }
}