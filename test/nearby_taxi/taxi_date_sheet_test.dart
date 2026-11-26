import 'package:bakhli/features/taxi/guest/v2/taxi_date_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../e2e_journeys/nearby/nearby_support.dart';
import '../ui_golden/golden_support.dart';

final _today = DateTime(2026, 11, 26);

class _Host extends StatelessWidget {
  const _Host({required this.onResult, this.initial});

  final ValueChanged<DateTime?> onResult;
  final DateTime? initial;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async => onResult(await TaxiDateSheet.pick(context, initial: initial ?? _today, today: _today)),
            child: const Text('open'),
          ),
        ),
      );
}

Future<void> _open(WidgetTester t, {required double w, required double s, required ValueChanged<DateTime?> onResult, DateTime? initial}) async {
  await pumpJourney(t, _Host(onResult: onResult, initial: initial), width: w, scale: s, height: 800);
  await t.tap(find.text('open'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });

  for (final w in [320.0, 360.0, 411.0]) {
    for (final s in [1.0, 1.3]) {
      testWidgets('sheet fits at ${w.toInt()} dp, text scale $s', (t) async {
        await _open(t, w: w, s: s, onResult: (_) {});
        expect(find.text('Date of journey'), findsOneWidget);
        expect(find.text('Today up to 90 days ahead'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('past days are not selectable and Done returns the picked day', (t) async {
    DateTime? got;
    await _open(t, w: 360, s: 1, onResult: (d) => got = d);
    await t.tap(find.text('20'));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('28'));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Done'));
    await t.pump(const Duration(milliseconds: 600));
    expect(got, DateTime(2026, 11, 28));
  });

  testWidgets('Done without a tap returns the starting day', (t) async {
    DateTime? got;
    await _open(t, w: 360, s: 1, onResult: (d) => got = d, initial: DateTime(2026, 11, 30));
    await t.tap(find.text('Done'));
    await t.pump(const Duration(milliseconds: 600));
    expect(got, DateTime(2026, 11, 30));
  });

  testWidgets('dismissing returns null', (t) async {
    var called = false;
    DateTime? got = DateTime(2000);
    await _open(t, w: 360, s: 1, onResult: (d) {
      called = true;
      got = d;
    });
    await t.tapAt(const Offset(10, 10));
    await t.pump(const Duration(milliseconds: 600));
    expect(called, isTrue);
    expect(got, isNull);
  });

  testWidgets('month arrows stop at the window and days after 90 are not selectable', (t) async {
    DateTime? got;
    await _open(t, w: 360, s: 1, onResult: (d) => got = d);
    expect(find.text('November, 2026'), findsOneWidget);
    await t.tap(find.byTooltip('Previous month'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('November, 2026'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await t.tap(find.byTooltip('Next month'));
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('February, 2027'), findsOneWidget);
    await t.tap(find.text('25'));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Done'));
    await t.pump(const Duration(milliseconds: 600));
    expect(got, DateTime(2026, 11, 26));
  });

  testWidgets('the month title has no jump picker', (t) async {
    await _open(t, w: 360, s: 1, onResult: (_) {});
    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    await t.tap(find.text('November, 2026'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('2026'), findsNothing);
  });
}
