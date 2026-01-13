import 'dart:io';
import 'package:args/args.dart';
import 'package:heart_beat/src/bridge/api_generated.dart/api.dart';
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
        print('Scan command not yet implemented');
        exit(1);

      case 'connect':
        print('Connect command not yet implemented');
        exit(1);

      case 'list-plans':
        print('List-plans command not yet implemented');
        exit(1);

      case 'start-workout':
        print('Start-workout command not yet implemented');
        exit(1);

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
