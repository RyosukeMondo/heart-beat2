import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden test helper utilities for visual regression testing.
///
/// This file provides utilities for:
/// - Creating consistent golden test wrappers with fixed sizing and theming
/// - Setting device pixel ratio for reproducible screenshots
/// - Managing golden file location and naming conventions
///
/// Golden tests capture screenshots of widgets and compare them against
/// baseline images to detect visual regressions. They are more fragile than
/// unit tests but catch layout, styling, and rendering issues.

/// Wraps a widget with MaterialApp and fixed sizing for golden tests.
///
/// This provides:
/// - Consistent Material 3 theme from app.dart
/// - Fixed viewport size (800x600) for reproducible screenshots
/// - Fixed device pixel ratio (1.0) to avoid font rendering differences
/// - MediaQuery context
///
/// Example:
/// ```dart
/// testWidgets('golden test', (tester) async {
///   await tester.pumpWidget(goldenWrapper(MyWidget()));
///   await expectLater(
///     find.byType(MyWidget),
///     matchesGoldenFile('goldens/my_widget.png'),
///   );
/// });
/// ```
Widget goldenWrapper(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? _defaultLightTheme(),
    home: SizedBox(
      width: 800,
      height: 600,
      child: Material(
        child: child,
      ),
    ),
  );
}

/// Default light theme matching app.dart configuration.
///
/// Uses Material 3 with red seed color matching the production app.
ThemeData _defaultLightTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.red,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
  );
}

/// Default dark theme matching app.dart configuration.
///
/// Uses Material 3 with red seed color matching the production app.
ThemeData defaultDarkTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.red,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );
}

/// Wraps a widget with dark theme for golden tests.
///
/// Example:
/// ```dart
/// await tester.pumpWidget(goldenWrapperDark(MyWidget()));
/// ```
Widget goldenWrapperDark(Widget child) {
  return goldenWrapper(child, theme: defaultDarkTheme());
}

/// Wraps a widget with custom size for golden tests.
///
/// Useful for testing widgets that need specific dimensions.
///
/// Example:
/// ```dart
/// await tester.pumpWidget(goldenWrapperWithSize(
///   child: MyWidget(),
///   width: 400,
///   height: 300,
/// ));
/// ```
Widget goldenWrapperWithSize({
  required Widget child,
  required double width,
  required double height,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? _defaultLightTheme(),
    home: SizedBox(
      width: width,
      height: height,
      child: Material(
        child: child,
      ),
    ),
  );
}

/// Configures device settings for reproducible golden tests.
///
/// Sets:
/// - Device pixel ratio to 1.0 (prevents font rendering differences)
/// - Fixed viewport size (800x600 by default)
///
/// Call this in setUp() for each golden test group.
///
/// Example:
/// ```dart
/// group('MyWidget golden tests', () {
///   setUp(() {
///     setupGoldenTest(tester);
///   });
///
///   testWidgets('renders correctly', (tester) async {
///     // ... test code
///   });
/// });
/// ```
void setupGoldenTest(WidgetTester tester, {Size? viewSize}) {
  final size = viewSize ?? const Size(800, 600);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
}

/// Resets device settings after golden tests.
///
/// Call this in tearDown() to restore default test settings.
///
/// Example:
/// ```dart
/// group('MyWidget golden tests', () {
///   tearDown(() {
///     tearDownGoldenTest(tester);
///   });
/// });
/// ```
void tearDownGoldenTest(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

/// Helper to pump widget and wait for golden test comparison.
///
/// Combines common golden test steps:
/// 1. Pump widget with goldenWrapper
/// 2. Wait for all animations to complete
/// 3. Perform golden comparison
///
/// Example:
/// ```dart
/// await pumpGolden(
///   tester: tester,
///   widget: MyWidget(),
///   goldenFile: 'goldens/my_widget.png',
/// );
/// ```
Future<void> pumpGolden({
  required WidgetTester tester,
  required Widget widget,
  required String goldenFile,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(goldenWrapper(widget, theme: theme));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(widget.runtimeType),
    matchesGoldenFile(goldenFile),
  );
}

/// Helper to pump widget with custom size and compare to golden.
///
/// Example:
/// ```dart
/// await pumpGoldenWithSize(
///   tester: tester,
///   widget: MyWidget(),
///   width: 400,
///   height: 300,
///   goldenFile: 'goldens/my_widget_small.png',
/// );
/// ```
Future<void> pumpGoldenWithSize({
  required WidgetTester tester,
  required Widget widget,
  required double width,
  required double height,
  required String goldenFile,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(goldenWrapperWithSize(
    child: widget,
    width: width,
    height: height,
    theme: theme,
  ));
  await tester.pumpAndSettle();
  await expectLater(
    find.byType(widget.runtimeType),
    matchesGoldenFile(goldenFile),
  );
}
