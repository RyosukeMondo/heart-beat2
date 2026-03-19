import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'golden_test_helpers.dart';

/// Test configuration for golden tests in this directory.
///
/// Flutter automatically loads this file before running any test in the same
/// directory. It installs [TolerantGoldenFileComparator] so that golden image
/// comparisons allow up to 1.5 % pixel difference, which accounts for minor
/// font anti-aliasing and rendering variations between local and CI
/// environments.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final configFile = Uri.file(
    '${Directory.current.path}/test/golden/flutter_test_config.dart',
  );
  goldenFileComparator = TolerantGoldenFileComparator(configFile);
  await testMain();
}
