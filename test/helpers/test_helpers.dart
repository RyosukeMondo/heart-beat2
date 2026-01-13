import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test helper utilities for widget testing.
///
/// This file provides utilities for:
/// - Creating test wrapper widgets with MaterialApp context
/// - Mocking Rust FFI calls (no device/emulator required)
/// - Common test patterns and helpers

/// Wraps a widget with MaterialApp for testing.
///
/// This provides the necessary context (Theme, MediaQuery, Navigator, etc.)
/// that most widgets require to render properly in tests.
///
/// Example:
/// ```dart
/// await tester.pumpWidget(testWrapper(MyWidget()));
/// ```
Widget testWrapper(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: child,
    ),
  );
}

/// Wraps a widget with MaterialApp and custom theme for testing.
///
/// Useful for testing widgets with specific theme requirements.
///
/// Example:
/// ```dart
/// await tester.pumpWidget(testWrapperWithTheme(
///   child: MyWidget(),
///   theme: ThemeData.dark(),
/// ));
/// ```
Widget testWrapperWithTheme({
  required Widget child,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? ThemeData.light(),
    home: Scaffold(
      body: child,
    ),
  );
}

/// Wraps a widget for bottom sheet testing.
///
/// Bottom sheets require Navigator context and proper Material ancestors.
/// This wrapper provides the necessary context.
///
/// Example:
/// ```dart
/// await tester.pumpWidget(bottomSheetWrapper(
///   builder: (context) => MyBottomSheet(),
/// ));
/// ```
Widget bottomSheetWrapper({
  required WidgetBuilder builder,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: builder,
                );
              },
              child: const Text('Show'),
            ),
          ),
        );
      },
    ),
  );
}

/// Test helper for pumping and settling with a custom duration.
///
/// Useful for widgets with animations or async state updates.
///
/// Example:
/// ```dart
/// await pumpAndSettle(tester, duration: Duration(milliseconds: 500));
/// ```
Future<void> pumpAndSettle(
  WidgetTester tester, {
  Duration? duration,
}) async {
  await tester.pump(duration);
  await tester.pumpAndSettle();
}

/// Finds a widget by key and verifies it exists.
///
/// Throws if the widget is not found.
///
/// Example:
/// ```dart
/// final widget = findByKeyAndVerify('myWidget');
/// expect(widget, findsOneWidget);
/// ```
Finder findByKeyAndVerify(String key) {
  final finder = find.byKey(Key(key));
  expect(finder, findsOneWidget, reason: 'Widget with key "$key" not found');
  return finder;
}

/// Verifies a text widget contains the expected text.
///
/// Example:
/// ```dart
/// verifyText('Hello World');
/// ```
void verifyText(String text) {
  expect(find.text(text), findsOneWidget,
      reason: 'Text "$text" not found in widget tree');
}

/// Verifies a widget of specific type exists.
///
/// Example:
/// ```dart
/// verifyWidgetType<CircularProgressIndicator>();
/// ```
void verifyWidgetType<T>() {
  expect(find.byType(T), findsOneWidget,
      reason: 'Widget of type ${T.toString()} not found');
}

/// Verifies a widget is not present in the tree.
///
/// Example:
/// ```dart
/// verifyNotPresent('errorMessage');
/// ```
void verifyNotPresent(String text) {
  expect(find.text(text), findsNothing,
      reason: 'Text "$text" should not be present');
}

/// Taps a widget and waits for animations to complete.
///
/// Example:
/// ```dart
/// await tapAndSettle(tester, find.byType(ElevatedButton));
/// ```
Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Verifies an icon is present by icon data.
///
/// Example:
/// ```dart
/// verifyIcon(Icons.error_outline);
/// ```
void verifyIcon(IconData iconData) {
  expect(find.byIcon(iconData), findsOneWidget,
      reason: 'Icon ${iconData.toString()} not found');
}

/// Mock callback tracker for testing widget callbacks.
///
/// Tracks invocations with optional argument capture.
///
/// Example:
/// ```dart
/// final callback = MockCallback<String>();
/// await tester.pumpWidget(testWrapper(
///   MyWidget(onSelect: callback.call),
/// ));
/// await tester.tap(find.text('Item'));
/// expect(callback.called, isTrue);
/// expect(callback.lastArg, equals('Item'));
/// ```
class MockCallback<T> {
  final List<T?> _calls = [];

  /// Whether the callback has been called at least once.
  bool get called => _calls.isNotEmpty;

  /// Number of times the callback was called.
  int get callCount => _calls.length;

  /// The last argument passed to the callback.
  T? get lastArg => _calls.isEmpty ? null : _calls.last;

  /// All arguments passed to the callback.
  List<T?> get allArgs => List.unmodifiable(_calls);

  /// The callback function to pass to widgets.
  void call([T? arg]) {
    _calls.add(arg);
  }

  /// Reset the callback state.
  void reset() {
    _calls.clear();
  }
}

/// Mock callback tracker for void callbacks (no arguments).
///
/// Example:
/// ```dart
/// final callback = MockVoidCallback();
/// await tester.pumpWidget(testWrapper(
///   MyWidget(onPressed: callback.call),
/// ));
/// await tester.tap(find.text('Button'));
/// expect(callback.called, isTrue);
/// expect(callback.callCount, equals(1));
/// ```
class MockVoidCallback {
  int _callCount = 0;

  /// Whether the callback has been called at least once.
  bool get called => _callCount > 0;

  /// Number of times the callback was called.
  int get callCount => _callCount;

  /// The callback function to pass to widgets.
  void call() {
    _callCount++;
  }

  /// Reset the callback state.
  void reset() {
    _callCount = 0;
  }
}
