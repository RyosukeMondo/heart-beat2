import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../utils/duration_helpers.dart';
import '../utils/zone_helpers.dart';
import '../utils/cue_helpers.dart';
import 'coaching_screen_state.dart';
import '../services/profile_service.dart';
import '../services/coaching_session_state.dart';

/// Coaching screen — primary surface during an active coaching session.
///
/// Shows:
/// - Current coaching cue card at top
/// - Live HR display (large BPM)
/// - Target HR band visualization
/// - Session timer + time-in-zone stats
/// - Pause / Stop controls
class CoachingScreen extends StatefulWidget {
  const CoachingScreen({super.key});

  @override
  State<CoachingScreen> createState() => _CoachingScreenState();
}

class _CoachingScreenState extends State<CoachingScreen> {
  late final CoachingScreenState _state;

  UserProfile get currentProfile =>
      ProfileService.instance.getCurrentProfile() ?? ProfileService.instance.getDefaultProfile();

  @override
  void initState() {
    super.initState();
    _state = CoachingScreenState(sessionState: CoachingSessionState());
    _state.setOnStateChange(_onStateChange);
    _state.initialize();
  }

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
        if (_state.currentCue != null) _buildCueCard(theme),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildHrDisplay(theme),
              const SizedBox(height: 24),
              _buildTargetBand(theme),
              const SizedBox(height: 24),
              _buildSessionStats(theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCueCard(ThemeData theme) {
    final cue = _state.currentCue!;
    final priorityColor = CueHelpers.cuePriorityColor(cue.priority);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: priorityColor.withValues(alpha: 0.15),
        border: Border.all(color: priorityColor, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CueHelpers.cueSourceIcon(cue.source), color: priorityColor, size: 20),
              const SizedBox(width: 8),
              Text(
                CueHelpers.cueLabelText(cue.label),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: priorityColor),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: priorityColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Text(CueHelpers.priorityLabel(cue.priority), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: priorityColor)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(cue.message, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text('BPM: ${_state.currentBpm}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
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

  Widget _buildTargetBand(ThemeData theme) {
    final profile = currentProfile;
    final maxHr = profile.effectiveMaxHr;
    final zones = profile.effectiveZones;

    final z1Pct = zones.zone1Max / 100.0;
    final z2Pct = zones.zone2Max / 100.0;
    final z3Pct = zones.zone3Max / 100.0;
    final z4Pct = zones.zone4Max / 100.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              _zoneLabel('Z1', Colors.blue),
              Expanded(child: _zoneLabel('Z2', Colors.green)),
              Expanded(child: _zoneLabel('Z3', Colors.yellow.shade700)),
              Expanded(child: _zoneLabel('Z4', Colors.orange)),
              _zoneLabel('Z5', Colors.red),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outline, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Row(
                children: [
                  _zoneFill(z1Pct, Colors.blue, _state.currentBpm / maxHr),
                  _zoneFill(z2Pct - z1Pct, Colors.green, _state.currentBpm / maxHr),
                  _zoneFill(z3Pct - z2Pct, Colors.yellow.shade700, _state.currentBpm / maxHr),
                  _zoneFill(z4Pct - z3Pct, Colors.orange, _state.currentBpm / maxHr),
                  _zoneFill(1.0 - z4Pct, Colors.red, _state.currentBpm / maxHr),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(maxHr * 0.5).round()}', style: theme.textTheme.labelSmall),
              Text('${(maxHr * 0.6).round()}', style: theme.textTheme.labelSmall),
              Text('${(maxHr * 0.7).round()}', style: theme.textTheme.labelSmall),
              Text('${(maxHr * 0.8).round()}', style: theme.textTheme.labelSmall),
              Text('${(maxHr * 0.9).round()}', style: theme.textTheme.labelSmall),
              Text('$maxHr', style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Target Zone: ${_state.currentZone.name.replaceAll('zone', 'Zone ')}',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _zoneLabel(String label, Color color) {
    return Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color), textAlign: TextAlign.center);
  }

  Widget _zoneFill(double fraction, Color color, double bpmFraction) {
    return Expanded(flex: (fraction * 100).round(), child: Container(color: color.withValues(alpha: 0.3)));
  }

  Widget _buildSessionStats(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem(theme, 'Session', DurationHelpers.formatDuration(_state.elapsed), Icons.timer),
          _statItem(theme, 'Zone', _state.currentZone.name.replaceAll('zone', 'Z'), ZoneHelpers.zoneIcon(_state.currentZone)),
        ],
      ),
    );
  }

  Widget _statItem(ThemeData theme, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

}