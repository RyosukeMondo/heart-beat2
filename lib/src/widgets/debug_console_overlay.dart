import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'debug_console.dart';

/// Wrapper widget that adds triple-tap gesture to toggle debug console overlay.
/// Only active in debug mode (kDebugMode). In release builds, acts as transparent wrapper.
class DebugConsoleOverlay extends StatefulWidget {
  /// The child widget to wrap.
  final Widget child;

  const DebugConsoleOverlay({
    super.key,
    required this.child,
  });

  @override
  State<DebugConsoleOverlay> createState() => _DebugConsoleOverlayState();
}

class _DebugConsoleOverlayState extends State<DebugConsoleOverlay> {
  /// Overlay entry for the debug console.
  OverlayEntry? _overlayEntry;

  /// Whether the debug console is currently visible.
  bool _isConsoleVisible = false;

  /// Track tap count and timing for triple-tap detection.
  int _tapCount = 0;
  DateTime _lastTapTime = DateTime.now();

  /// Maximum time between taps to count as triple-tap (milliseconds).
  static const int _tripleTapTimeoutMs = 500;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  /// Handle tap event for triple-tap detection.
  void _handleTap() {
    // Skip in release mode
    if (!kDebugMode) return;

    final now = DateTime.now();
    final timeSinceLastTap = now.difference(_lastTapTime).inMilliseconds;

    // Reset count if too much time has passed
    if (timeSinceLastTap > _tripleTapTimeoutMs) {
      _tapCount = 1;
    } else {
      _tapCount++;
    }

    _lastTapTime = now;

    // Toggle console on triple-tap
    if (_tapCount >= 3) {
      _toggleConsole();
      _tapCount = 0;
    }
  }

  /// Toggle debug console visibility.
  void _toggleConsole() {
    setState(() {
      if (_isConsoleVisible) {
        _removeOverlay();
      } else {
        _showOverlay();
      }
      _isConsoleVisible = !_isConsoleVisible;
    });
  }

  /// Show debug console overlay.
  void _showOverlay() {
    _overlayEntry = OverlayEntry(
      builder: (context) => _ConsoleOverlayWidget(
        onClose: _toggleConsole,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Remove debug console overlay.
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    // In release mode, just return the child without any gesture detection
    if (!kDebugMode) {
      return widget.child;
    }

    // In debug mode, wrap with gesture detector
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _handleTap,
      child: widget.child,
    );
  }
}

/// Positioned overlay widget containing the debug console.
class _ConsoleOverlayWidget extends StatefulWidget {
  final VoidCallback onClose;

  const _ConsoleOverlayWidget({
    required this.onClose,
  });

  @override
  State<_ConsoleOverlayWidget> createState() => _ConsoleOverlayWidgetState();
}

class _ConsoleOverlayWidgetState extends State<_ConsoleOverlayWidget> {
  /// Vertical position of the console (0.0 to 1.0).
  double _verticalPosition = 0.5;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final consoleHeight = screenHeight * 0.5;

    return Stack(
      children: [
        // Semi-transparent backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(
              color: Colors.black.withValues(alpha: 0.3),
            ),
          ),
        ),

        // Console positioned at bottom half
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: consoleHeight,
          child: Column(
            children: [
              // Drag handle
              GestureDetector(
                onVerticalDragStart: (details) {},
                onVerticalDragUpdate: (details) {
                  setState(() {
                    // Update position based on drag
                    final delta = details.delta.dy / screenHeight;
                    _verticalPosition = (_verticalPosition - delta).clamp(0.2, 0.8);
                  });
                },
                onVerticalDragEnd: (details) {},
                child: Container(
                  height: 32,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),

              // Debug console
              Expanded(
                child: DebugConsole(onClose: widget.onClose),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
