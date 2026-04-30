import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../utils/zone_helpers.dart';
import 'coaching_screen_state.dart';
import '../services/profile_service.dart';
import 'coaching_session_state.dart';
import '../widgets/cue_card.dart';
import '../widgets/target_band_visualization.dart';
import '../widgets/session_stats_card.dart';

/// Coaching screen — primary surface during an active coaching session.
///
/// Shows:
/// - Current coaching cue card at top
/// - Live HR display (large BPM)
/// - Target HR band visualization
/// - Session timer + time-in-zone stats
/// - Pause / Stop controls
class CoachingScreen extends StatefulWidget {
  const CoachingScreen({super.key, CoachingScreenState? state})
      : _state = state;

  final CoachingScreenState? _state;

  @override
  State<CoachingScreen> createState() => _CoachingScreenState(_state ?? _createDefaultState());

  static CoachingScreenState _createDefaultState([CoachingSessionState? sessionState]) =>
      CoachingScreenState.withDefaults(sessionState);
}

class _CoachingScreenState extends State<CoachingScreen> {
  _CoachingScreenState(this._state) {
    _state.setOnStateChange(_onStateChange);
    _state.initialize();
  }

  final CoachingScreenState _state;

  UserProfile get currentProfile =>
      ProfileService.instance.getCurrentProfile() ?? ProfileService.instance.getDefaultProfile();

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: const Key('coachingScreen'),
      appBar: AppBar(
        title: const Text('Coaching'),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        actions: [
          IconButton(
            icon: Icon(_state.isPaused ? Icons.play_arrow : Icons.pause),
            tooltip: _state.isPaused ? 'Resume' : 'Pause',
            onPressed: () => _state.togglePause(),
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            tooltip: 'Stop Session',
            onPressed: _stopSession,
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Future<void> _stopSession() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Session'),
        content: const Text('Are you sure you want to end this coaching session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _state.stopSession();
      if (mounted) Navigator.of(context).pop();
    }
  }

  Widget _buildBody(ThemeData theme) {
    return Column(
      children: [
        if (!_state.isConnected)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.orange.shade100,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Text('Not connected — waiting for HR data...', style: TextStyle(color: Colors.orange)),
              ],
            ),
          ),
        if (_state.currentCue != null) CueCard(cue: _state.currentCue!, currentBpm: _state.currentBpm),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHrDisplay(theme),
              const SizedBox(height: 24),
              TargetBandVisualization(
                currentBpm: _state.currentBpm,
                currentZone: _state.currentZone,
                profile: currentProfile,
              ),
              const SizedBox(height: 24),
              SessionStatsCard(elapsed: _state.elapsed, currentZone: _state.currentZone, zoneIcon: ZoneHelpers.zoneIcon(_state.currentZone)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHrDisplay(ThemeData theme) {
    return Column(
      children: [
        Text(
          '${_state.currentBpm}',
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: _state.isConnected ? ZoneHelpers.zoneColor(_state.currentZone) : theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
        Text('BPM', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300, color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
