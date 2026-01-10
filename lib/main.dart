import 'package:flutter/material.dart';
import 'package:heart_beat/src/app.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/frb_generated.dart';
import 'package:heart_beat/src/services/background_service.dart';

Future<void> main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Flutter Rust Bridge
  await RustLib.init();

  // Initialize background service configuration
  await BackgroundService.initializeService();

  // Run the app
  runApp(const MyApp());
}
