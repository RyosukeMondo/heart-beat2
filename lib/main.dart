import 'package:flutter/material.dart';
import 'package:heart_beat/src/app.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/frb_generated.dart';
import 'package:heart_beat/src/services/background_service.dart';
import 'package:heart_beat/src/services/log_service.dart';
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Flutter Rust Bridge
  await RustLib.init();

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
  try {
    await BackgroundService.initializeService();
  } catch (e) {
    debugPrint('Failed to initialize background service: $e');
    // Continue anyway - background service only needed for Android/iOS
  }

  // Run the app
  runApp(const MyApp());
}
