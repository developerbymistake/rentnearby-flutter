import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/taxi/guest/v2/taxi_search_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../e2e_journeys/nearby/nearby_support.dart';
import '../ui_golden/golden_support.dart';

const _widths = [320.0, 360.0, 411.0];
const _scales = [1.0, 1.3];

Future<void> _pump(
  WidgetTester t, {
  required double w,
  required double s,
  String from = 'Delhi',
  String? to = 'Rishikesh',
  bool isToday = true,
  bool canSwap = true,
  VoidCallback? onSwap,
  VoidCallback? onDate,
  VoidCallback? search,
  bool clearFrom = true,
}) =>
    pumpJourney(
      t,
      Scaffold(
        body: ListView(
          children: [
            TaxiSearchCard(
              fromLabel: from,
              toLabel: to,
              date: DateTime(2026, 11, 26),
              isToday: isToday,
              canSwap: canSwap,
              onFrom: () {},
              onTo: () {},
              onDate: onDate ?? () {},
              onSwap: onSwap ?? () {},
              onClearFrom: clearFrom ? () {} : null,
              onClearTo: to == null ? null : () {},
            ),
            SearchTaxisButton(onPressed: search),
          ],
        ),
      ),
      width: w,
      scale: s,
      height: 800,
    );

Rect _touchOf(WidgetTester t, IconData icon, {int index = 0}) {
  final box = find.ancestor(of: find.byIcon(icon).at(index), matching: find.byType(SizedBox)).first;
  return t.getRect(box);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadGoldenFonts();
  });

  for (final w in _widths) {
    for (final s in _scales) {
      testWidgets('fits at ${w.toInt()} dp, text scale $s, hit boxes apart', (t) async {
        await _pump(t, w: w, s: s, from: 'A very long place name somewhere in the hills of Kumaon', to: 'Another very long destination name in Garhwal');
        expect(t.takeException(), isNull);
        final swap = _touchOf(t, Icons.swap_vert_rounded);
        final clears = find.byIcon(Icons.close_rounded);
        expect(clears, findsNWidgets(2));
        for (var i = 0; i < 2; i++) {
          final x = _touchOf(t, Icons.close_rounded, index: i);
          expect(x.overlaps(swap), isFalse, reason: 'clear $i overlaps Swap');
          expect(swap.left - x.right, greaterThan(0), reason: 'clear $i touches Swap');
        }
        expect(_touchOf(t, Icons.close_rounded).overlaps(_touchOf(t, Icons.close_rounded, index: 1)), isFalse);
        expect(swap.width, greaterThanOrEqualTo(DS.s(KitMetrics.touch) - 0.01));
      });
    }
  }

  testWidgets('semantics labels', (t) async {
    final h = t.ensureSemantics();
    await _pump(t, w: 360, s: 1, to: null, clearFrom: false);
    expect(find.bySemanticsLabel('From, Delhi'), findsOneWidget);
    expect(find.bySemanticsLabel('To, Search a place'), findsOneWidget);
    expect(find.bySemanticsLabel('Date of journey, Today, Thu 26 Nov'), findsOneWidget);
    expect(find.bySemanticsLabel('Date of journey, Thu 26 Nov'), findsNothing);
    expect(find.bySemanticsLabel('Today'), findsNothing);
    expect(find.bySemanticsLabel('Swap From and To'), findsOneWidget);
    await _pump(t, w: 360, s: 1, to: null, clearFrom: false, isToday: false);
    expect(find.bySemanticsLabel('Date of journey, Thu 26 Nov'), findsOneWidget);
    expect(find.bySemanticsLabel('Date of journey, Today, Thu 26 Nov'), findsNothing);
    h.dispose();
  });

  testWidgets('Today chip only on today', (t) async {
    await _pump(t, w: 360, s: 1);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Thu 26 Nov'), findsOneWidget);
    await _pump(t, w: 360, s: 1, isToday: false);
    expect(find.text('Today'), findsNothing);
  });

  testWidgets('Swap off does nothing, on calls back', (t) async {
    var swaps = 0;
    await _pump(t, w: 360, s: 1, canSwap: false, onSwap: () => swaps++);
    await t.tap(find.byIcon(Icons.swap_vert_rounded));
    await t.pump(const Duration(milliseconds: 300));
    expect(swaps, 0);
    await _pump(t, w: 360, s: 1, onSwap: () => swaps++);
    await t.tap(find.byIcon(Icons.swap_vert_rounded));
    await t.pump(const Duration(milliseconds: 300));
    expect(swaps, 1);
  });

  testWidgets('Date row opens the sheet callback', (t) async {
    var dates = 0;
    await _pump(t, w: 360, s: 1, onDate: () => dates++);
    await t.tap(find.text('Thu 26 Nov'));
    await t.pump(const Duration(milliseconds: 300));
    expect(dates, 1);
  });

  testWidgets('Search taxis is off without a callback and on with one', (t) async {
    await _pump(t, w: 360, s: 1);
    PrimaryButton button() => t.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(find.text('Search taxis'), findsOneWidget);
    expect(button().onPressed, isNull);
    var taps = 0;
    await _pump(t, w: 360, s: 1, search: () => taps++);
    expect(button().onPressed, isNotNull);
    await t.tap(find.text('Search taxis'));
    await t.pump(const Duration(milliseconds: 300));
    expect(taps, 1);
  });

  testWidgets('long names end with an ellipsis on one line', (t) async {
    const long = 'A very long place name somewhere in the hills of Kumaon and beyond';
    await _pump(t, w: 320, s: 1.3, from: long);
    final text = t.widget<Text>(find.text(long));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });
}
