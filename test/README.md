# Flutter Widget Tests

Fast, isolated unit tests for Flutter widgets - no device or emulator required.

## Structure

```
test/
├── widget_test.dart           # Infrastructure smoke tests
├── helpers/
│   ├── test_helpers.dart     # Test wrapper widgets and utilities
│   └── mock_api.dart         # Mock Rust FFI API data
└── widgets/                  # Individual widget tests
    ├── hr_display_test.dart
    ├── zone_indicator_test.dart
    ├── plan_selector_test.dart
    ├── session_controls_test.dart
    └── connection_banner_test.dart
```

## Running Tests

```bash
# Run all widget tests
flutter test

# Run specific test file
flutter test test/widgets/hr_display_test.dart

# Run with coverage
flutter test --coverage

# Watch mode (auto-run on changes)
flutter test --watch
```

## Test Infrastructure

### Test Helpers (`helpers/test_helpers.dart`)

**Wrapper Widgets:**
- `testWrapper(Widget)` - Wraps widget with MaterialApp
- `testWrapperWithTheme(Widget, ThemeData)` - Custom theme wrapper
- `bottomSheetWrapper(WidgetBuilder)` - For bottom sheet testing

**Utilities:**
- `pumpAndSettle(WidgetTester)` - Pump with custom duration
- `tapAndSettle(WidgetTester, Finder)` - Tap and wait for animations
- `verifyText(String)` - Assert text is present
- `verifyIcon(IconData)` - Assert icon is present
- `verifyWidgetType<T>()` - Assert widget type exists

**Mock Callbacks:**
- `MockCallback<T>` - Track callback invocations with arguments
- `MockVoidCallback` - Track void callback invocations

Example:
```dart
final callback = MockCallback<String>();
await tester.pumpWidget(testWrapper(
  MyWidget(onSelect: callback.call),
));
await tester.tap(find.text('Item'));
expect(callback.called, isTrue);
expect(callback.lastArg, equals('Item'));
```

### Mock API (`helpers/mock_api.dart`)

Provides mock data for Rust FFI types without requiring device:

**MockPlans:**
```dart
MockPlans.defaultPlans  // Sample plan list
MockPlans.empty()       // No plans
MockPlans.failure(msg)  // Error state
```

**MockDevices:**
```dart
MockDevices.defaultDevices  // Sample BLE devices
MockDevices.device(id, name, rssi)
MockDevices.empty
```

**MockZone:**
```dart
MockZone.zones          // All 5 HR zones
MockZone.zoneName(zone) // Get zone name
MockZone.zoneColors     // Zone color mapping
```

**MockBattery:**
```dart
MockBattery.full        // 100%
MockBattery.low         // 25%
MockBattery.charging    // Charging state
```

## Writing Widget Tests

### Basic Pattern

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:heart_beat/src/widgets/my_widget.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('MyWidget', () {
    testWidgets('displays text correctly', (tester) async {
      await tester.pumpWidget(testWrapper(
        MyWidget(text: 'Hello'),
      ));

      expect(find.text('Hello'), findsOneWidget);
    });
  });
}
```

### Testing Callbacks

```dart
testWidgets('invokes callback on tap', (tester) async {
  final callback = MockCallback<String>();

  await tester.pumpWidget(testWrapper(
    MyWidget(onSelect: callback.call),
  ));

  await tester.tap(find.text('Button'));
  await tester.pump();

  expect(callback.called, isTrue);
  expect(callback.lastArg, equals('expected-value'));
});
```

### Testing Async State

```dart
testWidgets('shows loading then content', (tester) async {
  await tester.pumpWidget(testWrapper(MyWidget()));

  // Loading state
  expect(find.byType(CircularProgressIndicator), findsOneWidget);

  // Wait for async operation
  await tester.pumpAndSettle();

  // Content loaded
  expect(find.text('Content'), findsOneWidget);
});
```

### Testing Error States

```dart
testWidgets('shows error message on failure', (tester) async {
  await tester.pumpWidget(testWrapper(
    MyWidget(data: MockPlans.failure('Network error')),
  ));

  await tester.pumpAndSettle();

  expect(find.text('Network error'), findsOneWidget);
  expect(find.byIcon(Icons.error_outline), findsOneWidget);
});
```

## Test Guidelines

1. **No Device Required:** All tests must run without device/emulator
2. **Fast:** Keep tests under 100ms each
3. **Isolated:** Mock all Rust FFI calls and external dependencies
4. **Focused:** Test one widget at a time
5. **Coverage:** Test happy path, edge cases, and error states

## Common Patterns

### Testing Different States

```dart
group('MyWidget states', () {
  testWidgets('loading state', (tester) async { /* ... */ });
  testWidgets('success state', (tester) async { /* ... */ });
  testWidgets('error state', (tester) async { /* ... */ });
  testWidgets('empty state', (tester) async { /* ... */ });
});
```

### Testing Visual Output

```dart
testWidgets('applies correct styling', (tester) async {
  await tester.pumpWidget(testWrapper(MyWidget()));

  final text = tester.widget<Text>(find.text('BPM'));
  expect(text.style?.fontSize, equals(24));
  expect(text.style?.fontWeight, equals(FontWeight.w300));
});
```

### Testing Animations

```dart
testWidgets('animates transition', (tester) async {
  await tester.pumpWidget(testWrapper(MyWidget()));

  // Initial state
  expect(find.text('Initial'), findsOneWidget);

  // Trigger animation
  await tester.tap(find.text('Animate'));
  await tester.pump(); // Start animation
  await tester.pump(Duration(milliseconds: 500)); // Mid-animation
  await tester.pumpAndSettle(); // Complete animation

  // Final state
  expect(find.text('Final'), findsOneWidget);
});
```

## Troubleshooting

**Test fails with "No MediaQuery ancestor":**
- Wrap widget with `testWrapper()` to provide MaterialApp context

**Test fails with "A RenderFlex overflowed":**
- Wrap widget in `SingleChildScrollView` or constrain size with `SizedBox`

**Test hangs on pumpAndSettle:**
- Widget has infinite animation - use `pump(Duration)` instead

**Mock data constructor errors:**
- Check `mock_api.dart` for correct constructor signatures
- Opaque Rust types cannot be constructed - test widgets that receive data as props

## CI Integration

Tests run automatically in CI via `scripts/test-widgets.sh`:

```bash
./scripts/test-widgets.sh
```

Generates coverage report at `coverage/lcov.info`.
