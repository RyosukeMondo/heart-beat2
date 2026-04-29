import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:heart_beat/src/services/diagnosis_log_service.dart';
import 'package:heart_beat/src/services/profile_service.dart';
import 'package:heart_beat/src/services/background_service_provider.dart';
import 'package:heart_beat/src/services/connection_status_service.dart';
import 'package:heart_beat/src/screens/home_screen.dart';
import 'package:heart_beat/src/screens/session_screen.dart';
import 'package:heart_beat/src/screens/settings_screen.dart';
import 'package:heart_beat/src/screens/history_screen.dart';
import 'package:heart_beat/src/screens/session_detail_screen.dart';
import 'package:heart_beat/src/screens/workout_screen.dart';
import 'package:heart_beat/src/screens/plan_builder_screen.dart';
import 'package:heart_beat/src/screens/analytics_screen.dart';
import 'package:heart_beat/src/screens/readiness_screen.dart';
import 'package:heart_beat/src/screens/training_load_screen.dart';
import 'package:heart_beat/src/screens/calendar_screen.dart';
import 'package:heart_beat/src/screens/workout_library_screen.dart';
import 'package:heart_beat/src/widgets/debug_console_overlay.dart';
import 'package:heart_beat/src/screens/diagnosis_screen.dart';
import 'package:heart_beat/src/screens/coaching_screen.dart';
import 'package:heart_beat/src/screens/health_settings_screen.dart';
import 'package:heart_beat/src/screens/health_screen.dart';
import 'package:heart_beat/src/screens/zone_editor_screen.dart';
import 'package:heart_beat/src/services/coaching_cue_service.dart';

/// Main application widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DiagnosisLogService>.value(
          value: DiagnosisLogService.instance,
        ),
        Provider<ProfileService>.value(
          value: ProfileService.instance,
        ),
        ChangeNotifierProvider<BackgroundServiceProvider>.value(
          value: BackgroundServiceProvider.instance,
        ),
        ChangeNotifierProvider<ConnectionStatusServiceProvider>.value(
          value: ConnectionStatusServiceProvider.instance,
        ),
      ],
      child: DebugConsoleOverlay(
        child: MaterialApp(
          navigatorKey: navigatorKey,
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
            '/plan-builder': (context) => const PlanBuilderScreen(),
            '/analytics': (context) => const AnalyticsScreen(),
            '/readiness': (context) => const ReadinessScreen(),
            '/training-load': (context) => const TrainingLoadScreen(),
            '/calendar': (context) => const CalendarScreen(),
            '/workout-library': (context) => const WorkoutLibraryScreen(),
            '/diagnosis': (context) => const DiagnosisScreen(),
            '/coaching': (context) => const CoachingScreen(),
            '/health-settings': (context) => const HealthSettingsScreen(),
            '/health': (context) => const HealthScreen(),
            '/zone-editor': (context) => const ZoneEditorScreen(),
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
            // Handle /plan-builder/edit/:planName route
            if (settings.name?.startsWith('/plan-builder/edit/') == true) {
              final planName = settings.name!.substring(
                '/plan-builder/edit/'.length,
              );
              return MaterialPageRoute(
                builder: (context) => PlanBuilderScreen(editPlanName: planName),
                settings: settings,
              );
            }
            return null;
          },
          initialRoute: '/',
        ),
      ),
    );
  }
}
