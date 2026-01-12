import 'package:flutter/material.dart';
import '../bridge/api_generated.dart/api.dart' as api;

/// Widget displaying visual feedback when heart rate is outside the target zone.
///
/// Shows "SPEED UP" overlay when heart rate is too low and "SLOW DOWN" overlay
/// when too high. Uses animated opacity for attention-grabbing display while
/// remaining non-intrusive. Shows nothing when heart rate is in zone.
///
/// Designed to be highly visible at arm's length during active workouts.
class ZoneFeedbackWidget extends StatefulWidget {
  /// The current zone status from the workout progress.
  final api.ApiZoneStatus zoneStatus;

  const ZoneFeedbackWidget({
    super.key,
    required this.zoneStatus,
  });

  @override
  State<ZoneFeedbackWidget> createState() => _ZoneFeedbackWidgetState();
}

class _ZoneFeedbackWidgetState extends State<ZoneFeedbackWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  bool _isTooLow = false;
  bool _isTooHigh = false;
  bool _isInZone = true;

  @override
  void initState() {
    super.initState();

    // Animation controller for pulsing effect
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Opacity animation that pulses between 0.7 and 1.0
    _opacityAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.repeat(reverse: true);
    _updateZoneStatus();
  }

  @override
  void didUpdateWidget(ZoneFeedbackWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateZoneStatus();
  }

  Future<void> _updateZoneStatus() async {
    final isInZone = await api.zoneStatusIsInZone(status: widget.zoneStatus);
    final isTooLow = await api.zoneStatusIsTooLow(status: widget.zoneStatus);
    final isTooHigh = await api.zoneStatusIsTooHigh(status: widget.zoneStatus);

    if (mounted) {
      setState(() {
        _isInZone = isInZone;
        _isTooLow = isTooLow;
        _isTooHigh = isTooHigh;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if in zone
    if (_isInZone) {
      return const SizedBox.shrink();
    }

    // Determine overlay content based on zone status
    final Color backgroundColor;
    final String message;
    final IconData icon;

    if (_isTooLow) {
      backgroundColor = Colors.blue;
      message = 'SPEED UP';
      icon = Icons.arrow_upward;
    } else if (_isTooHigh) {
      backgroundColor = Colors.red;
      message = 'SLOW DOWN';
      icon = Icons.arrow_downward;
    } else {
      // Fallback case (shouldn't happen, but handle gracefully)
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 48),
        decoration: BoxDecoration(
          color: backgroundColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Large icon for visual emphasis
            Icon(
              icon,
              size: 72,
              color: Colors.white,
            ),
            const SizedBox(height: 12),
            // Bold, large text message
            Text(
              message,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
