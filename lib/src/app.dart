import 'package:flutter/material.dart';
import 'package:heart_beat/src/screens/home_screen.dart';
import 'package:heart_beat/src/screens/session_screen.dart';
import 'package:heart_beat/src/screens/settings_screen.dart';
import 'package:heart_beat/src/screens/history_screen.dart';
import 'package:heart_beat/src/screens/session_detail_screen.dart';
import 'package:heart_beat/src/screens/workout_screen.dart';
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
          '/history': (context) => const HistoryScreen(),
          '/session-detail': (context) => const SessionDetailScreen(),
        },
        onGenerateRoute: (settings) {
          // Handle /workout/:planName route
          if (settings.name?.startsWith('/workout/') == true) {
            final planName = settings.name!.substring('/workout/'.length);
            return MaterialPageRoute(
              builder: (context) => WorkoutScreen(planName: planName),
              settings: settings,
            );
          }
          return null;
        },
        initialRoute: '/',
      ),
    );
  }
}
