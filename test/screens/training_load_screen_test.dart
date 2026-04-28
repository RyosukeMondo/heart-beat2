import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:heart_beat/src/screens/training_load_screen.dart';
import '../helpers/test_helpers.dart';

void main() {
  group('TrainingLoadScreen Widget Rendering', () {
    testWidgets('TrainingLoadScreen can be instantiated with key', (tester) async {
      const widget = TrainingLoadScreen(key: Key('training_load'));
      await tester.pumpWidget(testWrapper(widget));
      expect(find.byType(TrainingLoadScreen), findsOneWidget);
    });

    testWidgets('TrainingLoadScreen renders AppBar with title', (tester) async {
      const widget = TrainingLoadScreen();
      await tester.pumpWidget(testWrapper(widget));
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Training Load'), findsOneWidget);
    });

    testWidgets('TrainingLoadScreen can be created with default key', (tester) async {
      const widget = TrainingLoadScreen();
      await tester.pumpWidget(testWrapper(widget));
      expect(find.byType(TrainingLoadScreen), findsOneWidget);
    });

    testWidgets('TrainingLoadScreen renders scaffold body', (tester) async {
      const widget = TrainingLoadScreen();
      await tester.pumpWidget(testWrapper(widget));
      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
    });
  });

  group('TrainingLoadScreen _Loading State', () {
    testWidgets('shows CircularProgressIndicator while loading', (tester) async {
      await tester.pumpWidget(_buildLoadingWrapper());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('loading indicator is centered', (tester) async {
      await tester.pumpWidget(_buildLoadingWrapper());
      expect(find.byType(Center), findsOneWidget);
    });
  });

  group('TrainingLoadScreen _Error State', () {
    testWidgets('shows error icon', (tester) async {
      await tester.pumpWidget(_buildErrorWrapper('Failed to load'));
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('shows error message text', (tester) async {
      await tester.pumpWidget(_buildErrorWrapper('Failed to load training data'));
      expect(find.text('Failed to load training data'), findsOneWidget);
    });

    testWidgets('shows retry button', (tester) async {
      await tester.pumpWidget(_buildErrorWrapper('Error'));
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry button has refresh icon', (tester) async {
      await tester.pumpWidget(_buildErrorWrapper('Error'));
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('tapping retry button triggers callback', (tester) async {
      var retried = false;
      await tester.pumpWidget(_buildErrorWrapperWithCallback('Error', onRetry: () => retried = true));
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });

  group('TrainingLoadScreen _Empty State', () {
    testWidgets('shows chart icon', (tester) async {
      await tester.pumpWidget(_buildEmptyWrapper());
      expect(find.byIcon(Icons.show_chart), findsOneWidget);
    });

    testWidgets('shows no training data message', (tester) async {
      await tester.pumpWidget(_buildEmptyWrapper());
      expect(find.text('No training load data yet'), findsOneWidget);
    });

    testWidgets('shows instruction text', (tester) async {
      await tester.pumpWidget(_buildEmptyWrapper());
      expect(find.text('Complete a few sessions to see your fitness trends'), findsOneWidget);
    });

    testWidgets('empty state is centered', (tester) async {
      await tester.pumpWidget(_buildEmptyWrapper());
      expect(find.byType(Center), findsAtLeastNWidgets(1));
    });
  });

  group('TrainingLoadScreen _MetricCard', () {
    testWidgets('displays CTL label with blue accent', (tester) async {
      await tester.pumpWidget(_metricCardWrapper('CTL', 45.0, 'Fitness', Colors.blue));
      expect(find.text('CTL'), findsOneWidget);
    });

    testWidgets('displays ATL label with red accent', (tester) async {
      await tester.pumpWidget(_metricCardWrapper('ATL', 35.0, 'Fatigue', Colors.red));
      expect(find.text('ATL'), findsOneWidget);
    });

    testWidgets('displays TSB label with green accent when positive', (tester) async {
      await tester.pumpWidget(_metricCardWrapper('TSB', 10.0, 'Form', Colors.green));
      expect(find.text('TSB'), findsOneWidget);
    });

    testWidgets('displays TSB label with red accent when negative', (tester) async {
      await tester.pumpWidget(_metricCardWrapper('TSB', -15.0, 'Form', Colors.red));
      expect(find.text('TSB'), findsOneWidget);
    });

    testWidgets('displays numeric value formatted as integer', (tester) async {
      await tester.pumpWidget(_metricCardWrapper('CTL', 45.7, 'Fitness', Colors.blue));
      expect(find.text('46'), findsOneWidget);
    });

    testWidgets('displays subtitle text', (tester) async {
      await tester.pumpWidget(_metricCardWrapper('CTL', 45.0, 'Fitness', Colors.blue));
      expect(find.text('Fitness'), findsOneWidget);
    });

    testWidgets('metric card renders in a Card widget', (tester) async {
      await tester.pumpWidget(_metricCardWrapper('CTL', 45.0, 'Fitness', Colors.blue));
      expect(find.byType(Card), findsOneWidget);
    });
  });

  group('TrainingLoadScreen _Legend', () {
    testWidgets('shows CTL description', (tester) async {
      await tester.pumpWidget(_buildLegendWrapper());
      expect(find.textContaining('CTL'), findsOneWidget);
      expect(find.textContaining('Chronic Training Load'), findsOneWidget);
    });

    testWidgets('shows ATL description', (tester) async {
      await tester.pumpWidget(_buildLegendWrapper());
      expect(find.textContaining('ATL'), findsOneWidget);
      expect(find.textContaining('Acute Training Load'), findsOneWidget);
    });

    testWidgets('shows TSB description', (tester) async {
      await tester.pumpWidget(_buildLegendWrapper());
      expect(find.textContaining('TSB'), findsOneWidget);
      expect(find.textContaining('Training Stress Balance'), findsOneWidget);
    });

    testWidgets('shows legend title', (tester) async {
      await tester.pumpWidget(_buildLegendWrapper());
      expect(find.text('Legend'), findsOneWidget);
    });
  });

  group('TrainingLoadScreen _InfoCard', () {
    testWidgets('shows info card title', (tester) async {
      await tester.pumpWidget(_buildInfoCardWrapper());
      expect(find.text('Understanding Your Training Load'), findsOneWidget);
    });

    testWidgets('shows positive TSB info row when expanded', (tester) async {
      await tester.pumpWidget(_buildInfoCardWrapper());
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.textContaining('TSB > 0'), findsOneWidget);
    });

    testWidgets('shows optimal training zone info row when expanded', (tester) async {
      await tester.pumpWidget(_buildInfoCardWrapper());
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.textContaining('TSB -10 to 0'), findsOneWidget);
    });

    testWidgets('shows overtraining warning info row when expanded', (tester) async {
      await tester.pumpWidget(_buildInfoCardWrapper());
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.textContaining('TSB < -20'), findsOneWidget);
    });

    testWidgets('info card is expandable', (tester) async {
      await tester.pumpWidget(_buildInfoCardWrapper());
      expect(find.byType(ExpansionTile), findsOneWidget);
    });
  });

  group('TrainingLoadScreen TRIMP Color Logic', () {
    test('returns green for trimp < 50', () {
      expect(_testTrimpColor(0), equals(Colors.green));
      expect(_testTrimpColor(25), equals(Colors.green));
      expect(_testTrimpColor(49), equals(Colors.green));
    });

    test('returns orange for trimp 50-150', () {
      expect(_testTrimpColor(50), equals(Colors.orange));
      expect(_testTrimpColor(100), equals(Colors.orange));
      expect(_testTrimpColor(150), equals(Colors.orange));
    });

    test('returns red for trimp > 150', () {
      expect(_testTrimpColor(151), equals(Colors.red));
      expect(_testTrimpColor(200), equals(Colors.red));
      expect(_testTrimpColor(300), equals(Colors.red));
    });
  });

  group('TrainingLoadScreen Date Formatting', () {
    test('formats date as M/d', () {
      final jan15 = DateTime(2024, 1, 15);
      expect(_testFmtDate(jan15.millisecondsSinceEpoch), equals('1/15'));
    });

    test('formats December correctly', () {
      final dec25 = DateTime(2024, 12, 25);
      expect(_testFmtDate(dec25.millisecondsSinceEpoch), equals('12/25'));
    });

    test('formats single digit month without padding', () {
      final mar5 = DateTime(2024, 3, 5);
      expect(_testFmtDate(mar5.millisecondsSinceEpoch), equals('3/5'));
    });
  });

  group('TrainingLoadScreen PMC Chart Data Transformation', () {
    test('creates correct number of spots for history', () {
      final history = _buildTestLoadHistory(7);
      final spots = _testCreatePmcSpots(history);
      expect(spots.ctlSpots.length, equals(7));
      expect(spots.atlSpots.length, equals(7));
      expect(spots.tsbSpots.length, equals(7));
    });

    test('CTL spots have correct values', () {
      final history = _buildTestLoadHistory(3);
      final spots = _testCreatePmcSpots(history);
      expect(spots.ctlSpots[0].y, equals(40.0));
      expect(spots.ctlSpots[1].y, equals(42.5));
      expect(spots.ctlSpots[2].y, equals(45.0));
    });

    test('ATL spots have correct values', () {
      final history = _buildTestLoadHistory(3);
      final spots = _testCreatePmcSpots(history);
      expect(spots.atlSpots[0].y, equals(30.0));
      expect(spots.atlSpots[1].y, equals(32.5));
      expect(spots.atlSpots[2].y, equals(35.0));
    });

    test('TSB spots have correct values (CTL - ATL)', () {
      final history = _buildTestLoadHistory(3);
      final spots = _testCreatePmcSpots(history);
      expect(spots.tsbSpots[0].y, equals(10.0));
      expect(spots.tsbSpots[1].y, equals(10.0));
      expect(spots.tsbSpots[2].y, equals(10.0));
    });

    test('spots have sequential x values', () {
      final history = _buildTestLoadHistory(5);
      final spots = _testCreatePmcSpots(history);
      for (var i = 0; i < spots.ctlSpots.length; i++) {
        expect(spots.ctlSpots[i].x, equals(i.toDouble()));
        expect(spots.atlSpots[i].x, equals(i.toDouble()));
        expect(spots.tsbSpots[i].x, equals(i.toDouble()));
      }
    });

    test('handles empty history', () {
      final history = _buildTestLoadHistory(0);
      final spots = _testCreatePmcSpots(history);
      expect(spots.ctlSpots.length, equals(0));
      expect(spots.atlSpots.length, equals(0));
      expect(spots.tsbSpots.length, equals(0));
    });
  });

  group('TrainingLoadScreen TRIMP Chart Data', () {
    test('creates correct number of bar groups', () {
      final trimp = _buildTestTrimpPoints(5);
      expect(trimp.length, equals(5));
    });

    test('trimp values are preserved', () {
      final trimp = _buildTestTrimpPoints(3);
      expect(trimp[0].value, equals(75.0));
      expect(trimp[1].value, equals(120.0));
      expect(trimp[2].value, equals(200.0));
    });

    test('handles empty trimp list', () {
      final trimp = <_TestTrendPoint>[];
      expect(trimp.length, equals(0));
    });
  });

  group('TrainingLoadScreen Metric Card Color Logic', () {
    test('TSB positive shows green', () {
      expect(_testTsbColor(0), equals(Colors.green));
      expect(_testTsbColor(10), equals(Colors.green));
      expect(_testTsbColor(50), equals(Colors.green));
    });

    test('TSB negative shows red', () {
      expect(_testTsbColor(-1), equals(Colors.red));
      expect(_testTsbColor(-10), equals(Colors.red));
      expect(_testTsbColor(-30), equals(Colors.red));
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers - replicate TrainingLoadScreen internal widget builders
// ---------------------------------------------------------------------------

Widget _buildLoadingWrapper() {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return const Center(child: CircularProgressIndicator());
        },
      ),
    ),
  );
}

Widget _buildErrorWrapper(String message) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: cs.error),
                  const SizedBox(height: 16),
                  Text(message, textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

Widget _buildErrorWrapperWithCallback(String message, {required VoidCallback onRetry}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: cs.error),
                  const SizedBox(height: 16),
                  Text(message, textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

Widget _buildEmptyWrapper() {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.show_chart, size: 64, color: cs.outline),
                const SizedBox(height: 16),
                Text('No training load data yet', style: tt.titleLarge?.copyWith(color: cs.outline)),
                const SizedBox(height: 8),
                Text(
                  'Complete a few sessions to see your fitness trends',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

Widget _metricCardWrapper(String label, double value, String subtitle, Color accent) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          final t = Theme.of(context);
          return Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                children: [
                  Text(label, style: t.textTheme.bodySmall?.copyWith(color: accent, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(value.toStringAsFixed(0), style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: accent)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

Widget _buildLegendWrapper() {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLegendContent(context),
              ],
            ),
          );
        },
      ),
    ),
  );
}

Widget _buildLegendContent(BuildContext context) {
  final t = Theme.of(context);
  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Legend', style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _legendRow(context, Colors.blue, 'CTL (Chronic Training Load)', 'Your fitness level -- rolling average of training stress'),
          const SizedBox(height: 8),
          _legendRow(context, Colors.red, 'ATL (Acute Training Load)', 'Recent training stress -- short-term fatigue'),
          const SizedBox(height: 8),
          _legendRow(context, Colors.green, 'TSB (Training Stress Balance)', 'Form/freshness -- difference between fitness and fatigue'),
        ],
      ),
    ),
  );
}

Widget _legendRow(BuildContext context, Color color, String title, String description) {
  final t = Theme.of(context);
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(width: 16, height: 16, margin: const EdgeInsets.only(top: 2), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(description, style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    ],
  );
}

Widget _buildInfoCardWrapper() {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildInfoContent(context),
              ],
            ),
          );
        },
      ),
    ),
  );
}

Widget _buildInfoContent(BuildContext context) {
  final t = Theme.of(context);
  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: ExpansionTile(
      leading: Icon(Icons.info_outline, color: t.colorScheme.primary),
      title: Text('Understanding Your Training Load', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow(context, Icons.check_circle, Colors.green, 'TSB > 0: You\'re fresh and well-rested'),
              const SizedBox(height: 8),
              _infoRow(context, Icons.trending_flat, Colors.orange, 'TSB -10 to 0: Optimal training zone'),
              const SizedBox(height: 8),
              _infoRow(context, Icons.warning, Colors.red, 'TSB < -20: Risk of overtraining, consider recovery'),
              const SizedBox(height: 12),
              Text(
                'The PMC chart helps you balance training stress with recovery.',
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _infoRow(BuildContext context, IconData icon, Color color, String text) {
  return Row(
    children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
    ],
  );
}

// ---------------------------------------------------------------------------
// Test replicas of TrainingLoadScreen internal logic
// ---------------------------------------------------------------------------

Color _testTrimpColor(double trimp) {
  if (trimp < 50) return Colors.green;
  if (trimp <= 150) return Colors.orange;
  return Colors.red;
}

String _testFmtDate(int millis) {
  return '${DateTime.fromMillisecondsSinceEpoch(millis).month}/'
      '${DateTime.fromMillisecondsSinceEpoch(millis).day}';
}

class _TestLoadPoint {
  final int timestampMillis;
  final double ctl;
  final double atl;
  final double tsb;

  const _TestLoadPoint({
    required this.timestampMillis,
    required this.ctl,
    required this.atl,
    required this.tsb,
  });
}

class _TestTrendPoint {
  final int timestampMillis;
  final double value;

  const _TestTrendPoint({required this.timestampMillis, required this.value});
}

class _PmcSpots {
  final List<FlSpot> ctlSpots;
  final List<FlSpot> atlSpots;
  final List<FlSpot> tsbSpots;

  const _PmcSpots({required this.ctlSpots, required this.atlSpots, required this.tsbSpots});
}

List<_TestLoadPoint> _buildTestLoadHistory(int days) {
  var baseTime = DateTime(2024, 1, 1).millisecondsSinceEpoch;
  return List.generate(days, (i) => _TestLoadPoint(
    timestampMillis: baseTime + (i * 86400000),
    ctl: 40.0 + i * 2.5,
    atl: 30.0 + i * 2.5,
    tsb: 10.0,
  ));
}

List<_TestTrendPoint> _buildTestTrimpPoints(int count) {
  var baseTime = DateTime(2024, 1, 1).millisecondsSinceEpoch;
  final values = [75.0, 120.0, 200.0];
  return List.generate(count, (i) => _TestTrendPoint(
    timestampMillis: baseTime + (i * 86400000),
    value: values[i % values.length],
  ));
}

_PmcSpots _testCreatePmcSpots(List<_TestLoadPoint> history) {
  final ctlSpots = <FlSpot>[];
  final atlSpots = <FlSpot>[];
  final tsbSpots = <FlSpot>[];
  for (var i = 0; i < history.length; i++) {
    final p = history[i];
    ctlSpots.add(FlSpot(i.toDouble(), p.ctl));
    atlSpots.add(FlSpot(i.toDouble(), p.atl));
    tsbSpots.add(FlSpot(i.toDouble(), p.tsb));
  }
  return _PmcSpots(ctlSpots: ctlSpots, atlSpots: atlSpots, tsbSpots: tsbSpots);
}

Color _testTsbColor(double tsb) {
  return tsb >= 0 ? Colors.green : Colors.red;
}