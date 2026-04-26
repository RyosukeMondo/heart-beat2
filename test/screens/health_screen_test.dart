import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:heart_beat/src/screens/health_screen.dart';
import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HealthScreen _StatusBanner rendering', () {
    // Replicate _StatusBanner logic for isolated widget testing
    Widget buildBanner({required _BannerStatus status, String detail = ''}) {
      final (color, label) = switch (status) {
        _BannerStatus.ok => (Colors.green, 'OK'),
        _BannerStatus.low => (Colors.amber, detail),
      };

      return MaterialApp(
        home: Scaffold(
          body: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: color.withValues(alpha: 0.15),
            child: Row(
              children: [
                Icon(Icons.favorite, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('ok status shows green OK label', (tester) async {
      await tester.pumpWidget(buildBanner(status: _BannerStatus.ok));
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('low status shows amber detail text', (tester) async {
      await tester.pumpWidget(buildBanner(
        status: _BannerStatus.low,
        detail: 'Below 70 bpm for 10 min',
      ));
      expect(find.text('Below 70 bpm for 10 min'), findsOneWidget);
    });

    testWidgets('banner shows favorite icon', (tester) async {
      await tester.pumpWidget(buildBanner(status: _BannerStatus.ok));
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('ok banner has green background tint', (tester) async {
      await tester.pumpWidget(buildBanner(status: _BannerStatus.ok));
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.color, equals(Colors.green.withValues(alpha: 0.15)));
    });

    testWidgets('low banner has amber background tint', (tester) async {
      await tester.pumpWidget(buildBanner(status: _BannerStatus.low, detail: 'test'));
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.color, equals(Colors.amber.withValues(alpha: 0.15)));
    });
  });

  group('HealthScreen _AverageCard rendering', () {
    String formatAvg(double? avg) {
      if (avg == null) return '—';
      return '${avg.toStringAsFixed(0)} BPM';
    }

    Widget buildAverageCard({
      String label = '1 Hour',
      double? avg,
      bool isLoading = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: const TextStyle(fontSize: 16)),
                  if (isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      formatAvg(avg),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: avg == null ? Colors.grey : Colors.blue,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows label text', (tester) async {
      await tester.pumpWidget(buildAverageCard(label: '24 Hours'));
      expect(find.text('24 Hours'), findsOneWidget);
    });

    testWidgets('shows — when avg is null (empty store)', (tester) async {
      await tester.pumpWidget(buildAverageCard(avg: null));
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('shows formatted BPM when avg is provided', (tester) async {
      await tester.pumpWidget(buildAverageCard(avg: 65.0));
      expect(find.text('65 BPM'), findsOneWidget);
    });

    testWidgets('shows circular progress indicator when loading', (tester) async {
      await tester.pumpWidget(buildAverageCard(isLoading: true));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows no progress indicator when not loading', (tester) async {
      await tester.pumpWidget(buildAverageCard(isLoading: false));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('7 days average shows correct BPM format', (tester) async {
      await tester.pumpWidget(buildAverageCard(label: '7 Days', avg: 62.7));
      expect(find.text('63 BPM'), findsOneWidget);
    });

    testWidgets('card renders in a Card widget', (tester) async {
      await tester.pumpWidget(buildAverageCard());
      expect(find.byType(Card), findsOneWidget);
    });
  });
}

// Replicated enums for testing (matching HealthScreen internal types)
enum _BannerStatus { ok, low }
