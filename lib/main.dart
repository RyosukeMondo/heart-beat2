import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode;

import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;
import 'package:heart_beat/src/app.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/frb_generated.dart';
import 'package:heart_beat/src/services/background_service.dart';
import 'package:heart_beat/src/services/coaching_cue_service.dart';
import 'package:heart_beat/src/services/health_alert_service.dart';
import 'package:heart_beat/src/services/log_service.dart';
import 'package:heart_beat/src/services/voice_coaching_service.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Flutter Rust Bridge.
  // iOS/macOS link libheart_beat.a statically via -force_load, so symbols live
  // in the main executable — resolve them via ExternalLibrary.process rather
  // than the default loader, which would try to dlopen a non-existent framework.
  await RustLib.init(
    externalLibrary: (Platform.isIOS || Platform.isMacOS)
        ? ExternalLibrary.process(iKnowHowToUseIt: true)
        : null,
  );

  // Start the embedded debug HTTP/WS server on port 8888 (debug builds only).
  // The server is reachable from the Mac via `iproxy 8888 8888`.
  if (kDebugMode) {
    try {
      await startDebugServer(port: 8888);
      debugPrint('[heart_beat] Debug server listening on http://localhost:8888');
    } catch (e) {
      debugPrint('[heart_beat] Failed to start debug server: $e');
    }
  }

  // Set data directory for file storage (required on Android)
  try {
    final appDir = await getApplicationDocumentsDirectory();
    await setDataDir(path: appDir.path);

    // Seed default training plans if none exist
    final plansCreated = await seedDefaultPlans();
    if (plansCreated > 0) {
      debugPrint('Created $plansCreated default training plans');
    }
  } catch (e) {
    debugPrint('Failed to set data directory: $e');
    // Continue anyway - will fail later if file APIs are used
  }

  // Initialize panic handler and logging system
  try {
    await initPanicHandler();
    final logStream = initLogging();
    LogService.instance.subscribe(logStream);
    // Initialize Dart-side log capture (debugPrint hook, rolling file writer, error handlers)
    await LogService.instance.initialize();
  } catch (e) {
    debugPrint('Failed to initialize logging system: $e');
    // Continue anyway - app can function without logging
  }

  // Initialize platform-specific BLE requirements (Android JNI)
  try {
    await initPlatform();
  } catch (e) {
    debugPrint('Failed to initialize BLE platform: $e');
    // Continue anyway - error will surface when BLE operations are attempted
  }

  // Initialize background service configuration
  try {
    await BackgroundService.initializeService();
  } catch (e) {
    debugPrint('Failed to initialize background service: $e');
    // Continue anyway - background service only needed for Android/iOS
  }

  // Initialize coaching cue service (FFI stream + delivery surfaces)
  try {
    // Wire up CoachingCueService with VoiceCoachingService concrete.
    // This keeps CoachingCueService decoupled from VoiceCoachingService.
    CoachingCueService.setInstance(
      CoachingCueService.create(VoiceCoachingService.instance),
    );
    await CoachingCueService.instance.initialize();
    await CoachingCueService.instance.initializeTts();
    // Initialize coaching engine in Rust before connecting
    await initCoachingEngine();
    // Subscribe to coaching cue stream from Rust rule engine
    CoachingCueService.instance.startCueListener();
    // HealthAlertService listens to the same cue stream independently
    HealthAlertService.instance.startListening(
      CoachingCueService.instance.cueStream.map(
        (cue) => RawCue(label: cue.label, message: cue.message),
      ),
    );
    if (kDebugMode) {
      debugPrint('[heart_beat] CoachingCueService stream subscribed');
    }
  } catch (e) {
    debugPrint('Failed to initialize coaching cue service: $e');
    // Continue anyway - coaching is non-critical
  }

  // Run the app
  runApp(const MyApp());
}
