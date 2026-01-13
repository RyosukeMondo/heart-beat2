import 'dart:io';
import 'package:args/args.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/domain/heart_rate.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/frb_generated.dart';

/// Dart CLI for Heart Beat - exercises the same code paths as Flutter UI
/// for rapid testing without device deployment.
Future<void> main(List<String> arguments) async {
  // Set up argument parser
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help message',
    )
    ..addFlag(
      'version',
      abbr: 'v',
      negatable: false,
      help: 'Show version information',
    );

  // Add subcommands (will be implemented in subsequent tasks)
  final scanParser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help for scan command');
  parser.addCommand('scan', scanParser);

  final connectParser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help for connect command')
    ..addOption('device', abbr: 'd', help: 'Device ID to connect to');
  parser.addCommand('connect', connectParser);

  final listPlansParser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help for list-plans command');
  parser.addCommand('list-plans', listPlansParser);

  final startWorkoutParser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help for start-workout command')
    ..addOption('plan', abbr: 'p', help: 'Name of the training plan');
  parser.addCommand('start-workout', startWorkoutParser);

  final historyParser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help for history command');
  parser.addCommand('history', historyParser);

  final profileParser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help for profile command')
    ..addOption('age', help: 'Set age')
    ..addOption('max-hr', help: 'Set maximum heart rate');
  parser.addCommand('profile', profileParser);

  try {
    final results = parser.parse(arguments);

    // Show version
    if (results['version'] as bool) {
      print('Heart Beat CLI v1.0.0');
      print('Dart CLI for testing Flutter/Rust integration');
      exit(0);
    }

    // Show help
    if (results['help'] as bool || results.command == null) {
      printUsage(parser);
      exit(0);
    }

    // Handle commands
    final command = results.command;
    if (command == null) {
      printUsage(parser);
      exit(1);
    }

    // Check if help is requested for command before initializing Rust bridge
    final bool commandHelp = command['help'] as bool? ?? false;

    switch (command.name) {
      case 'scan':
        if (commandHelp) {
          printCommandHelp('scan', 'Scan for BLE devices', scanParser);
          exit(0);
        }
        break;

      case 'connect':
        if (commandHelp) {
          printCommandHelp('connect', 'Connect to a BLE device and stream HR data', connectParser);
          exit(0);
        }
        break;

      case 'list-plans':
        if (commandHelp) {
          printCommandHelp('list-plans', 'List available training plans', listPlansParser);
          exit(0);
        }
        break;

      case 'start-workout':
        if (commandHelp) {
          printCommandHelp('start-workout', 'Start a workout session', startWorkoutParser);
          exit(0);
        }
        break;

      case 'history':
        if (commandHelp) {
          printCommandHelp('history', 'View workout history', historyParser);
          exit(0);
        }
        break;

      case 'profile':
        if (commandHelp) {
          printCommandHelp('profile', 'View and modify user profile', profileParser);
          exit(0);
        }
        break;

      default:
        stderr.writeln('Unknown command: ${command.name}');
        printUsage(parser);
        exit(1);
    }

    // Initialize Rust bridge (only if we get past help commands)
    await initializeRustBridge();

    // Execute actual commands
    switch (command.name) {
      case 'scan':
        await handleScanCommand();
        exit(0);

      case 'connect':
        final deviceId = command['device'] as String?;
        if (deviceId == null || command.rest.isNotEmpty) {
          // Support both --device and positional argument
          final finalDeviceId = deviceId ?? (command.rest.isNotEmpty ? command.rest[0] : null);
          if (finalDeviceId == null) {
            stderr.writeln('Error: Device ID is required');
            stderr.writeln('Usage: dart run bin/dart_cli.dart connect <device_id>');
            stderr.writeln('   or: dart run bin/dart_cli.dart connect --device <device_id>');
            exit(1);
          }
          await handleConnectCommand(finalDeviceId);
        } else {
          await handleConnectCommand(deviceId);
        }
        exit(0);

      case 'list-plans':
        await handleListPlansCommand();
        exit(0);

      case 'start-workout':
        final planName = command['plan'] as String?;
        if (planName == null || command.rest.isNotEmpty) {
          // Support both --plan and positional argument
          final finalPlanName = planName ?? (command.rest.isNotEmpty ? command.rest[0] : null);
          if (finalPlanName == null) {
            stderr.writeln('Error: Plan name is required');
            stderr.writeln('Usage: dart run bin/dart_cli.dart start-workout <plan_name>');
            stderr.writeln('   or: dart run bin/dart_cli.dart start-workout --plan <plan_name>');
            exit(1);
          }
          await handleStartWorkoutCommand(finalPlanName);
        } else {
          await handleStartWorkoutCommand(planName);
        }
        exit(0);

      case 'history':
        print('History command not yet implemented');
        exit(1);

      case 'profile':
        print('Profile command not yet implemented');
        exit(1);

      default:
        stderr.writeln('Unknown command: ${command.name}');
        printUsage(parser);
        exit(1);
    }
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    printUsage(parser);
    exit(1);
  } catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  }
}

/// Initialize the Rust bridge without Flutter dependencies
Future<void> initializeRustBridge() async {
  try {
    // Initialize Flutter Rust Bridge
    await RustLib.init();

    // Initialize panic handler
    await initPanicHandler();

    // Set data directory for file storage
    final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (homeDir != null) {
      final dataDir = '$homeDir/.heart_beat';
      final dir = Directory(dataDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await setDataDir(path: dataDir);

      // Seed default training plans if none exist
      final plansCreated = await seedDefaultPlans();
      if (plansCreated > 0) {
        print('Created $plansCreated default training plans');
      }
    }

    // Initialize platform-specific BLE requirements
    await initPlatform();
  } catch (e) {
    stderr.writeln('Failed to initialize Rust bridge: $e');
    exit(1);
  }
}

/// Print usage information
void printUsage(ArgParser parser) {
  print('Heart Beat CLI - Test Flutter/Rust integration from command line\n');
  print('Usage: dart run bin/dart_cli.dart <command> [options]\n');
  print('Available commands:');
  print('  scan           Scan for BLE heart rate monitors');
  print('  connect        Connect to a device and stream heart rate');
  print('  list-plans     List available training plans');
  print('  start-workout  Start a workout session');
  print('  history        View past workout sessions');
  print('  profile        View and modify user profile\n');
  print('Global options:');
  print(parser.usage);
  print('\nRun "dart run bin/dart_cli.dart <command> --help" for more information on a command.');
}

/// Print command-specific help
void printCommandHelp(String command, String description, ArgParser? parser) {
  print('$command - $description\n');
  print('Usage: dart run bin/dart_cli.dart $command [options]\n');
  if (parser != null) {
    print('Options:');
    print(parser.usage);
  }
}

/// Handle scan command - scan for BLE devices
Future<void> handleScanCommand() async {
  try {
    print('Scanning for BLE devices...');
    print('This may take a few seconds...\n');

    final devices = await scanDevices();

    if (devices.isEmpty) {
      print('No devices found.');
      print('\nMake sure:');
      print('  - Bluetooth is enabled');
      print('  - Your heart rate monitor is nearby and powered on');
      print('  - The app has necessary permissions');
      return;
    }

    print('Found ${devices.length} device(s):\n');

    // Sort by signal strength (RSSI) - stronger signals first
    devices.sort((a, b) => b.rssi.compareTo(a.rssi));

    for (final device in devices) {
      final name = device.name ?? '(unnamed)';
      final rssi = device.rssi;
      final signal = _formatSignalStrength(rssi);

      print('  ${device.id}');
      print('    Name:   $name');
      print('    Signal: $signal ($rssi dBm)');
      print('');
    }

    print('To connect to a device, use:');
    print('  dart run bin/dart_cli.dart connect --device <device_id>');
  } catch (e) {
    stderr.writeln('Error scanning for devices: $e');
    stderr.writeln('\nTroubleshooting:');
    stderr.writeln('  - Ensure Bluetooth is enabled');
    stderr.writeln('  - Check that the app has necessary permissions');
    stderr.writeln('  - On Linux, you may need to run with sudo or add your user to the bluetooth group');
    rethrow;
  }
}

/// Format signal strength for display
String _formatSignalStrength(int rssi) {
  if (rssi >= -50) {
    return 'Excellent';
  } else if (rssi >= -60) {
    return 'Good';
  } else if (rssi >= -70) {
    return 'Fair';
  } else if (rssi >= -80) {
    return 'Weak';
  } else {
    return 'Very Weak';
  }
}

/// Handle connect command - connect to device and stream HR data
Future<void> handleConnectCommand(String deviceId) async {
  try {
    print('Connecting to device: $deviceId');
    print('This may take a few seconds...\n');

    // Connect to the device
    await connectDevice(deviceId: deviceId);
    print('✓ Connected successfully!\n');

    // Create HR stream
    final hrStream = createHrStream();

    print('Streaming heart rate data (press Ctrl+C to stop):\n');
    print('Time       | Raw BPM | Filtered BPM');
    print('-----------+---------+-------------');

    // Set up signal handler for graceful shutdown
    bool shouldExit = false;

    // Listen to Ctrl+C
    ProcessSignal.sigint.watch().listen((_) async {
      if (!shouldExit) {
        shouldExit = true;
        print('\n\nDisconnecting...');
        await disconnect();
        print('Disconnected.');
        exit(0);
      }
    });

    // Stream heart rate data
    await for (final hrData in hrStream) {
      if (shouldExit) break;

      final rawBpm = await hrRawBpm(data: hrData);
      final filteredBpm = await hrFilteredBpm(data: hrData);
      final now = DateTime.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      print('$timeStr   | ${rawBpm.toString().padLeft(7)} | ${filteredBpm.toString().padLeft(12)}');
    }

  } catch (e) {
    stderr.writeln('\nError connecting to device: $e');
    stderr.writeln('\nTroubleshooting:');
    stderr.writeln('  - Verify the device ID is correct (use scan command)');
    stderr.writeln('  - Ensure the device is powered on and nearby');
    stderr.writeln('  - Check that Bluetooth is enabled');
    stderr.writeln('  - Make sure the device is not already connected to another app');

    // Try to disconnect cleanly
    try {
      await disconnect();
    } catch (_) {
      // Ignore disconnect errors during error handling
    }

    rethrow;
  }
}

/// Handle list-plans command - list available training plans
Future<void> handleListPlansCommand() async {
  try {
    print('Loading training plans...\n');

    final plans = await listPlans();

    if (plans.isEmpty) {
      print('No training plans found.');
      print('\nTraining plans should be stored in:');
      final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (homeDir != null) {
        print('  $homeDir/.heart_beat/');
      }
      return;
    }

    print('Available training plans (${plans.length}):\n');

    for (int i = 0; i < plans.length; i++) {
      print('  ${i + 1}. ${plans[i]}');
    }

    print('\nTo start a workout, use:');
    print('  dart run bin/dart_cli.dart start-workout <plan_name>');
  } catch (e) {
    stderr.writeln('Error listing plans: $e');
    stderr.writeln('\nTroubleshooting:');
    stderr.writeln('  - Check that training plans exist in the data directory');
    stderr.writeln('  - Verify file permissions');
    rethrow;
  }
}

/// Handle start-workout command - start workout and stream progress
Future<void> handleStartWorkoutCommand(String planName) async {
  try {
    print('Starting workout: $planName');
    print('Initializing session...\n');

    // Start the workout
    await startWorkout(planName: planName);
    print('✓ Workout started!\n');

    // Create session progress stream
    final progressStream = createSessionProgressStream();

    print('Workout Progress:');
    print('═══════════════════════════════════════════════════════════════════\n');

    // Set up signal handlers for pause/resume/stop
    bool shouldExit = false;
    bool isPaused = false;

    // Setup stdin in line mode for keyboard input
    stdin.echoMode = false;
    stdin.lineMode = false;

    // Listen to Ctrl+C for graceful shutdown
    ProcessSignal.sigint.watch().listen((_) async {
      if (!shouldExit) {
        shouldExit = true;
        print('\n\n╔═══════════════════════════════════════╗');
        print('║  Stopping workout...                  ║');
        print('╚═══════════════════════════════════════╝\n');
        await stopWorkout();
        print('Workout stopped. Session saved.');
        exit(0);
      }
    });

    // Instructions
    print('Controls:');
    print('  [p] - Pause/Resume');
    print('  [q] or Ctrl+C - Stop and save');
    print('─────────────────────────────────────────────────────────────────\n');

    // Listen to keyboard input in background
    stdin.listen((List<int> data) async {
      if (shouldExit) return;

      final key = String.fromCharCodes(data).toLowerCase();

      if (key == 'p') {
        if (isPaused) {
          print('\n▶ Resuming workout...\n');
          await resumeWorkout();
          isPaused = false;
        } else {
          print('\n⏸ Pausing workout...\n');
          await pauseWorkout();
          isPaused = true;
        }
      } else if (key == 'q') {
        shouldExit = true;
        print('\n\n╔═══════════════════════════════════════╗');
        print('║  Stopping workout...                  ║');
        print('╚═══════════════════════════════════════╝\n');
        await stopWorkout();
        print('Workout stopped. Session saved.');
        exit(0);
      }
    });

    // Stream workout progress
    String? lastPhase;
    int updateCount = 0;

    await for (final progress in progressStream) {
      if (shouldExit) break;

      // Get progress data
      final phaseProgress = await sessionProgressPhaseProgress(progress: progress);
      final phaseName = await phaseProgressPhaseName(progress: phaseProgress);
      final phaseIndex = await phaseProgressPhaseIndex(progress: phaseProgress);
      final targetZone = await phaseProgressTargetZone(progress: phaseProgress);
      final elapsedSecs = await phaseProgressElapsedSecs(progress: phaseProgress);
      final remainingSecs = await phaseProgressRemainingSecs(progress: phaseProgress);
      final currentBpm = await sessionProgressCurrentBpm(progress: progress);
      final zoneStatus = await sessionProgressZoneStatus(progress: progress);
      final isInZone = await zoneStatusIsInZone(status: zoneStatus);
      final zoneStatusStr = await zoneStatusToString(status: zoneStatus);

      // Print phase change header
      if (lastPhase != phaseName) {
        lastPhase = phaseName;
        print('\n╔═══════════════════════════════════════════════════════════════╗');
        print('║  Phase ${phaseIndex + 1}: $phaseName');
        print('║  Target: ${_formatZone(targetZone)}');
        print('╚═══════════════════════════════════════════════════════════════╝\n');
      }

      // Update progress display (every second)
      updateCount++;
      if (updateCount % 1 == 0) {  // Update every update
        final elapsed = _formatTime(elapsedSecs);
        final remaining = _formatTime(remainingSecs);
        final zoneIndicator = isInZone ? '✓' : '✗';
        final pauseIndicator = isPaused ? ' [PAUSED]' : '';

        // Clear line and print update
        stdout.write('\r${' ' * 100}');  // Clear line
        stdout.write('\r  $elapsed | BPM: ${currentBpm.toString().padLeft(3)} | $zoneStatusStr $zoneIndicator | Remaining: $remaining$pauseIndicator');
      }
    }

    // Workout completed naturally
    if (!shouldExit) {
      print('\n\n╔═══════════════════════════════════════╗');
      print('║  🎉 Workout Complete!                 ║');
      print('╚═══════════════════════════════════════╝\n');
      print('Session saved successfully.');
    }

  } catch (e) {
    stderr.writeln('\n\nError during workout: $e');
    stderr.writeln('\nTroubleshooting:');
    stderr.writeln('  - Verify the plan name is correct (use list-plans command)');
    stderr.writeln('  - Ensure training plan file is valid JSON');
    stderr.writeln('  - Check that you are connected to a heart rate monitor (use connect command first)');

    // Try to stop workout cleanly
    try {
      await stopWorkout();
    } catch (_) {
      // Ignore stop errors during error handling
    }

    rethrow;
  } finally {
    // Restore terminal settings
    stdin.echoMode = true;
    stdin.lineMode = true;
  }
}

/// Format time in seconds to MM:SS
String _formatTime(int seconds) {
  final mins = seconds ~/ 60;
  final secs = seconds % 60;
  return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

/// Format zone for display
String _formatZone(Zone zone) {
  switch (zone) {
    case Zone.zone1:
      return 'Zone 1 (50-60% max HR, Recovery)';
    case Zone.zone2:
      return 'Zone 2 (60-70% max HR, Fat Burning)';
    case Zone.zone3:
      return 'Zone 3 (70-80% max HR, Aerobic)';
    case Zone.zone4:
      return 'Zone 4 (80-90% max HR, Threshold)';
    case Zone.zone5:
      return 'Zone 5 (90-100% max HR, Max Effort)';
  }
}
