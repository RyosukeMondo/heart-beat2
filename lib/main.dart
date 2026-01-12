import 'package:flutter/material.dart';
import 'package:heart_beat/src/app.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/frb_generated.dart';
import 'package:heart_beat/src/services/background_service.dart';
import 'package:heart_beat/src/services/log_service.dart';

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Flutter Rust Bridge
  await RustLib.init();

  // Initialize panic handler and logging system
  try {
    await initPanicHandler();
    final logStream = await initLogging();
    LogService.instance.subscribe(logStream);
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
  await BackgroundService.initializeService();

  // Run the app
  runApp(const MyApp());
}
