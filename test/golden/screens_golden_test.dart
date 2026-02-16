import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/screens/home_screen.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/domain/heart_rate.dart';
import 'package:heart_beat/src/widgets/hr_display.dart';
import 'package:heart_beat/src/widgets/zone_indicator.dart';
import 'package:heart_beat/src/widgets/phase_progress.dart';
import 'golden_test_helpers.dart';

/// Golden tests for full screen layouts.
///
/// These tests capture screenshots of complete screens to detect layout
/// regressions in:
/// - Overall screen structure and spacing
/// - AppBar layout and actions
/// - Widget composition and positioning
/// - Responsive behavior at fixed viewport size
///
/// Note: These tests use widget compositions rather than live screens to avoid
/// the need for mocking complex API calls, streams, and navigation dependencies.
///
/// Run with:
///   flutter test test/golden/screens_golden_test.dart
///
/// Update golden files with:
///   flutter test test/golden/screens_golden_test.dart --update-goldens
void main() {
  group('Screen Golden Tests', () {
    testWidgets('home screen with empty device list', (tester) async {
      // Arrange
      setupGoldenTest(tester, viewSize: const Size(600, 900));

      // Act - Test the HomeScreen widget directly
      await tester.pumpWidget(
        goldenWrapperWithSize(
          child: const HomeScreen(),
          width: 600,
          height: 900,
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/home_screen_empty.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('session screen mockup with heart rate display', (tester) async {
      // Arrange
      setupGoldenTest(tester, viewSize: const Size(600, 900));

      // Create a mockup of the session screen layout without the complex state management
      final sessionScreenMockup = Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Polar H10 9C3A5F19'),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            leading: const BackButton(),
            actions: const [
              IconButton(
                icon: Icon(Icons.bluetooth_disabled),
                onPressed: null,
              ),
            ],
          ),
        body: Column(
          children: [
            // Connection banner placeholder (not shown when connected)
            const SizedBox.shrink(),

            // Main content
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // BPM Display
                    const HrDisplay(bpm: 145),

                    const SizedBox(height: 32),

                    // Zone Indicator
                    const ZoneIndicator(zone: Zone.zone3),

                    const SizedBox(height: 32),

                    // Battery Indicator placeholder
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha:0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.battery_full, size: 20, color: Colors.green),
                          SizedBox(width: 4),
                          Text('85%', style: TextStyle(color: Colors.green)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Workout'),
          ),
        ),
      );

      // Act
      await tester.pumpWidget(
        goldenWrapperWithSize(
          child: sessionScreenMockup,
          width: 600,
          height: 900,
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/session_screen.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('workout screen mockup during active phase', (tester) async {
      // Arrange
      setupGoldenTest(tester, viewSize: const Size(600, 900));

      // Create a mockup of the workout screen layout
      final workoutScreenMockup = Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('30-Min Endurance'),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            leading: const BackButton(),
          ),
        body: Column(
          children: [
            // Connection banner removed for testing (requires Rust bridge initialization)

            // Main content area
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Heart rate display
                    const HrDisplay(bpm: 152),

                    const SizedBox(height: 32),

                    // Zone indicator
                    const ZoneIndicator(zone: Zone.zone4),

                    const SizedBox(height: 32),

                    // Zone feedback placeholder
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('In Target Zone', style: TextStyle(color: Colors.green)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Phase progress widget
                    const PhaseProgressWidget(
                      phaseName: 'Active Interval',
                      targetZone: Zone.zone4,
                      elapsedSecs: 180,
                      remainingSecs: 120,
                    ),

                    const SizedBox(height: 16),

                    // Total time remaining
                    const Text(
                      'Total remaining: 18:45',
                      style: TextStyle(fontSize: 16),
                    ),

                    const SizedBox(height: 8),

                    // State indicator
                    Text(
                      'Running',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Control buttons placeholder
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      );

      // Act
      await tester.pumpWidget(
        goldenWrapperWithSize(
          child: workoutScreenMockup,
          width: 600,
          height: 900,
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/workout_screen.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('workout screen mockup during warmup phase', (tester) async {
      // Arrange
      setupGoldenTest(tester, viewSize: const Size(600, 900));

      // Create a mockup of the workout screen during warmup
      final workoutWarmupMockup = Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Morning Run'),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            leading: const BackButton(),
          ),
        body: Column(
          children: [
            // Connection banner removed for testing (requires Rust bridge initialization)

            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const HrDisplay(bpm: 98),
                    const SizedBox(height: 32),
                    const ZoneIndicator(zone: Zone.zone2),
                    const SizedBox(height: 32),

                    // Zone feedback - too low
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_upward, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Speed Up', style: TextStyle(color: Colors.blue)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    const PhaseProgressWidget(
                      phaseName: 'Warmup',
                      targetZone: Zone.zone2,
                      elapsedSecs: 60,
                      remainingSecs: 240,
                    ),

                    const SizedBox(height: 16),
                    const Text('Total remaining: 25:00', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Running', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      );

      // Act
      await tester.pumpWidget(
        goldenWrapperWithSize(
          child: workoutWarmupMockup,
          width: 600,
          height: 900,
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/workout_screen_warmup.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });

    testWidgets('workout screen mockup during cooldown phase', (tester) async {
      // Arrange
      setupGoldenTest(tester, viewSize: const Size(600, 900));

      // Create a mockup of the workout screen during cooldown
      final workoutCooldownMockup = Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('HIIT Session'),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            leading: const BackButton(),
          ),
        body: Column(
          children: [
            // Connection banner removed for testing (requires Rust bridge initialization)

            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const HrDisplay(bpm: 128),
                    const SizedBox(height: 32),
                    const ZoneIndicator(zone: Zone.zone2),
                    const SizedBox(height: 32),

                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('In Target Zone', style: TextStyle(color: Colors.green)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    const PhaseProgressWidget(
                      phaseName: 'Cooldown',
                      targetZone: Zone.zone2,
                      elapsedSecs: 120,
                      remainingSecs: 180,
                    ),

                    const SizedBox(height: 16),
                    const Text('Total remaining: 3:00', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Running', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                  ),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      );

      // Act
      await tester.pumpWidget(
        goldenWrapperWithSize(
          child: workoutCooldownMockup,
          width: 600,
          height: 900,
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/workout_screen_cooldown.png'),
      );

      // Cleanup
      tearDownGoldenTest(tester);
    });
  });
}
