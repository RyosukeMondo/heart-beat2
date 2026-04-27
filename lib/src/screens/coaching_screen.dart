import 'package:flutter/material.dart';
import '../services/coaching_session_state.dart';
import '../services/coaching_screen_streams.dart';
import '../bridge/api_generated.dart/api.dart' as api;
import '../bridge/api_generated.dart/domain/heart_rate.dart';
import '../services/profile_service.dart';

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
  final CoachingSessionState _sessionState = CoachingSessionState();
  final CoachingScreenStreams _streams = CoachingScreenStreams();

  int _currentBpm = 0;
  Zone _currentZone = Zone.zone1;
  bool _isConnected = false;
  api.ApiCue? _currentCue;
  final ProfileService _profileService = ProfileService.instance;

  @override
  void initState() {
    super.initState();
    _profileService.loadProfile();
    _sessionState.start();
    _sessionState.onUpdate = _onSessionUpdate;
    _streams.onHrData = _onHrData;
    _streams.onStatusChange = _onStatusChange;
    _streams.onCue = _onCue;
    _streams.subscribe();
  }

  void _onSessionUpdate(Duration elapsed, Map<Zone, Duration> zoneTime) {
    if (!mounted) return;
    setState(() {});
  }

  void _onHrData(api.ApiFilteredHeartRate data) async {
    final bpm = await api.hrFilteredBpm(data: data);
    final zone = _profileService.getZoneForBpm(bpm) ?? Zone.zone1;

    if (!mounted) return;
    setState(() {
      _currentBpm = bpm;
      _currentZone = zone;
    });
    _sessionState.onZoneTick(zone);
  }

  void _onStatusChange(api.ApiConnectionStatus status) async {
    if (!mounted) return;
    final isConn = await api.connectionStatusIsConnected(status: status);
    setState(() {
      _isConnected = isConn;
    });
  }

  void _onCue(api.ApiCue cue) {
    if (!mounted) return;
    setState(() {
      _currentCue = cue;
    });
  }

  void _togglePause() {
    _sessionState.togglePause();
    if (!mounted) return;
    setState(() {});
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
      await api.disconnect();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }

  @override
  void dispose() {
    _streams.dispose();
    _sessionState.dispose();
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
            icon: Icon(_sessionState.isPaused ? Icons.play_arrow : Icons.pause),
            tooltip: _sessionState.isPaused ? 'Resume' : 'Pause',
            onPressed: _togglePause,
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

  Widget _buildBody(ThemeData theme) {
    return Column(
      children: [
        // Stale data banner
        if (!_isConnected)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.orange.shade100,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Text(
                  'Not connected — waiting for HR data...',
                  style: TextStyle(color: Colors.orange),
                ),
              ],
            ),
          ),

        // Current cue card
        if (_currentCue != null) _buildCueCard(theme),

        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Live HR display
              _buildHrDisplay(theme),

              const SizedBox(height: 24),

              // Target band visualization
              _buildTargetBand(theme),

              const SizedBox(height: 24),

              // Session stats
              _buildSessionStats(theme),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCueCard(ThemeData theme) {
    final cue = _currentCue!;
    final priorityColor = _cuePriorityColor(cue.priority);

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
              Icon(_cueSourceIcon(cue.source), color: priorityColor, size: 20),
              const SizedBox(width: 8),
              Text(
                _cueLabelText(cue.label),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: priorityColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _priorityLabel(cue.priority),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: priorityColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            cue.message,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'BPM: $_currentBpm',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHrDisplay(ThemeData theme) {
    return Column(
      children: [
        if (!_isConnected)
          Text(
            '$_currentBpm',
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          )
        else
          Text(
            '$_currentBpm',
            style: TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: _zoneColor(_currentZone),
            ),
          ),
        Text(
          'BPM',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w300,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildTargetBand(ThemeData theme) {
    final profile = _profileService.getCurrentProfile() ?? _profileService.getDefaultProfile();
    final maxHr = profile.effectiveMaxHr;
    final zones = profile.effectiveZones;

    // Zone percentages
    final z1Pct = zones.zone1Max / 100.0;
    final z2Pct = zones.zone2Max / 100.0;
    final z3Pct = zones.zone3Max / 100.0;
    final z4Pct = zones.zone4Max / 100.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Zone label bar
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

          // Target band gauge
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
                  _zoneFill(z1Pct, Colors.blue, _currentBpm / maxHr),
                  _zoneFill(z2Pct - z1Pct, Colors.green, _currentBpm / maxHr),
                  _zoneFill(z3Pct - z2Pct, Colors.yellow.shade700, _currentBpm / maxHr),
                  _zoneFill(z4Pct - z3Pct, Colors.orange, _currentBpm / maxHr),
                  _zoneFill(1.0 - z4Pct, Colors.red, _currentBpm / maxHr),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // BPM markers
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

          // Target zone indicator
          Text(
            'Target Zone: ${_currentZone.name.replaceAll('zone', 'Zone ')}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoneLabel(String label, Color color) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: color,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _zoneFill(double fraction, Color color, double bpmFraction) {
    return Expanded(
      flex: (fraction * 100).round(),
      child: Container(color: color.withValues(alpha: 0.3)),
    );
  }

  Widget _buildSessionStats(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem(
            theme,
            'Session',
            _formatDuration(_sessionState.elapsed),
            Icons.timer,
          ),
          _statItem(
            theme,
            'Zone',
            _currentZone.name.replaceAll('zone', 'Z'),
            _zoneIcon(_currentZone),
          ),
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
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Color _zoneColor(Zone zone) {
    switch (zone) {
      case Zone.zone1:
        return Colors.blue;
      case Zone.zone2:
        return Colors.green;
      case Zone.zone3:
        return Colors.yellow.shade700;
      case Zone.zone4:
        return Colors.orange;
      case Zone.zone5:
        return Colors.red;
    }
  }

  IconData _zoneIcon(Zone zone) {
    switch (zone) {
      case Zone.zone1:
        return Icons.airline_seat_recline_extra;
      case Zone.zone2:
        return Icons.directions_walk;
      case Zone.zone3:
        return Icons.directions_run;
      case Zone.zone4:
        return Icons.sports_gymnastics;
      case Zone.zone5:
        return Icons.local_fire_department;
    }
  }

  Color _cuePriorityColor(int priority) {
    switch (priority) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _priorityLabel(int priority) {
    switch (priority) {
      case 0:
        return 'LOW';
      case 1:
        return 'NORMAL';
      case 2:
        return 'HIGH';
      case 3:
        return 'CRITICAL';
      default:
        return 'UNKNOWN';
    }
  }

  IconData _cueSourceIcon(int source) {
    switch (source) {
      case 0:
        return Icons.track_changes;
      case 1:
        return Icons.airline_seat_flat;
      case 2:
        return Icons.whatshot;
      default:
        return Icons.info;
    }
  }

  String _cueLabelText(String label) {
    switch (label) {
      case 'raise_hr':
        return 'Raise HR';
      case 'cool_down':
        return 'Cool Down';
      case 'stand_up':
        return 'Stand Up';
      case 'ease_off':
        return 'Ease Off';
      default:
        return label.replaceAll('_', ' ').split(' ').map((w) =>
          w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : ''
        ).join(' ');
    }
  }
}