import 'package:flutter/material.dart';
import 'package:heart_beat/src/screens/home_screen.dart';
import 'package:heart_beat/src/screens/session_screen.dart';
import 'package:heart_beat/src/screens/settings_screen.dart';
import 'package:heart_beat/src/screens/session_detail_screen.dart';
import 'package:heart_beat/src/widgets/debug_console_overlay.dart';

/// Main application widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DebugConsoleOverlay(
      child: MaterialApp(
        title: 'Heart Beat',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.red,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.red,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        routes: {
          '/': (context) => const HomeScreen(),
          '/session': (context) => const SessionScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/session-detail': (context) => const SessionDetailScreen(),
        },
        initialRoute: '/',
      ),
    );
  }
}
