import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_result_model.dart';
import 'package:bakhli/features/trip/widgets/drag/trip_spot_drag_scope.dart';
import 'package:bakhli/features/trip/widgets/trip_day_spot_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/drag_rig.dart';
import 'support/engine_rig.dart';

typedef _Rows = Map<Element, (int, Widget)>;

int _dayOf(Element e) {
  var day = -1;
  e.visitAncestorElements((a) {
    final w = a.widget;
    if (w is TripDaySpotList) {
      day = w.day;
      return false;
    }
    return true;
  });
  return day;
}

bool _inPage(Element e) {
  var under = false;
  e.visitAncestorElements((a) {
    if (a.widget is TripSpotDragScope) {
      under = true;
      return false;
    }
    return true;
  });
  return under;
}

_Rows _snapshot() => {
      for (final e in find.byElementPredicate((e) => isRow(e.widget) && _inPage(e)).evaluate()) e: (_dayOf(e), e.widget),
    };

Map<int, int> _rebuilt(_Rows before) {
  final out = <int, int>{};
  for (final MapEntry(key: e, value: (day, _)) in _snapshot().entries) {
    final old = before[e];
    if (old == null || !identical(old.$2, e.widget)) out[day] = (out[day] ?? 0) + 1;
  }
  return out;
}

final _fixtures = <String, List<int>>{
  '1x30': [30],
  '3x12': [12, 12, 12],
  '6x8': [8, 8, 8, 8, 8, 8],
  '14x6': List.filled(14, 6),
};

final _report = <String>[];

TripPlanResult _resultFor(TripPlan p) => TripPlanResult(
      days: [
        for (final d in p.days)
          TripPlanDay(
            day: d.day,
            spotIds: [for (final s in d.spots) s.id],
            visitMinutes: 0,
            driveMinutes: 0,
            totalMinutes: 0,
            km: 0,
            overLimit: false,
            isEstimate: false,
            legs: [
              for (var i = 0; i + 1 < d.spots.length; i++)
                TripLeg(fromId: d.spots[i].id, toId: d.spots[i + 1].id, minutes: 10 + i, km: 1, isEstimate: false),
            ],
          ),
      ],
      warnings: const [],
      osrmAvailable: true,
      dayLimitMinutes: 300,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);
  tearDownAll(() => debugPrint('PERF\n${_report.join('\n')}'));

  for (final MapEntry(key: name, value: perDay) in _fixtures.entries) {
    testWidgets('finger move rebuilds no row ($name)', (t) async {
      await pumpDragPlan(t, enginePlan([perDay]));
      final h = rowHeight(t, 'L1d1s0');
      final g = await pressAndMove(t, t.getCenter(handleOf('L1d1s0')), h * 0.3, steps: 3);
      await t.pump(const Duration(milliseconds: 300));
      var worst = 0;
      var worstMs = 0.0;
      for (var i = 0; i < 6; i++) {
        final before = _snapshot();
        await g.moveBy(Offset(0, h * 0.4));
        final sw = Stopwatch()..start();
        await t.pump(const Duration(milliseconds: 16));
        sw.stop();
        final r = _rebuilt(before).values.fold(0, (a, b) => a + b);
        if (r > worst) worst = r;
        if (sw.elapsedMicroseconds / 1000 > worstMs) worstMs = sw.elapsedMicroseconds / 1000;
      }
      expect(worst, 0);
      await g.up();
      await settleDrop(t);
      _report.add('move $name: rows rebuilt $worst, worst move frame ${worstMs.toStringAsFixed(1)} ms');
      await drainDrag(t);
    });

    testWidgets('in-day drop rebuilds only rows of that day ($name)', (t) async {
      final c = await pumpDragPlan(t, enginePlan([perDay]), reduceMotion: true);
      final dayRows = perDay.first;
      final before = _snapshot();
      final g = await pressAndMove(t, t.getCenter(handleOf('L1d1s0')), rowHeight(t, 'L1d1s0') * 2.2, steps: 8);
      final sw = Stopwatch()..start();
      await g.up();
      await t.pump();
      sw.stop();
      expect(dayIds(c, 1).indexOf('L1d1s0'), 2);
      final r = _rebuilt(before);
      expect(r[1] ?? 0, lessThanOrEqualTo(dayRows));
      expect(r.keys.where((d) => d != 1), isEmpty, reason: '$r');
      _report.add('drop $name: rows rebuilt ${r[1] ?? 0} of $dayRows in day 1, other days 0, drop frame ${(sw.elapsedMicroseconds / 1000).toStringAsFixed(1)} ms');

      final p = c.plan.value!;
      c.result.value = _resultFor(p);
      await t.pump();
      final before2 = _snapshot();
      final next = _resultFor(p);
      c.result.value = TripPlanResult(
        days: [
          for (final d in next.days)
            d.day == 1
                ? TripPlanDay(
                    day: 1,
                    spotIds: d.spotIds,
                    visitMinutes: 0,
                    driveMinutes: 0,
                    totalMinutes: 0,
                    km: 0,
                    overLimit: false,
                    isEstimate: false,
                    legs: [for (final l in d.legs) l.toId == d.spotIds.last ? TripLeg(fromId: l.fromId, toId: l.toId, minutes: 99, km: 1, isEstimate: false) : l],
                  )
                : d,
        ],
        warnings: const [],
        osrmAvailable: true,
        dayLimitMinutes: 300,
      );
      await t.pump();
      final r2 = _rebuilt(before2);
      expect(r2.keys.where((d) => d != 1), isEmpty, reason: '$r2');
      expect(r2[1] ?? 0, lessThanOrEqualTo(2));
      await drainDrag(t);
    });
  }

  // Day 2 keeps room for one more place so the cross-day drop is allowed.
  final crossFixtures = <String, List<int>>{
    '3x12': [12, 5, 12],
    '6x8': [8, 5, 8, 8, 8, 8],
    '14x6': [6, 5, ...List.filled(12, 6)],
  };
  for (final MapEntry(key: name, value: perDay) in crossFixtures.entries) {
    testWidgets('cross-day drag: target change rebuilds at most 2 day cards and no row, drop only the two days ($name)', (t) async {
      final c = await pumpDragPlan(t, enginePlan([perDay]), reduceMotion: true);
      final rowsBefore = _snapshot();
      final start = t.getCenter(handleOf('L1d1s0'));
      final rowCentre = t.getCenter(row('L1d1s0'));
      final d2 = [for (var i = 0; i < perDay[1]; i++) t.getRect(row('L1d2s$i'))];
      final d3Top = t.getRect(row('L1d3s0')).top;
      final g = await t.startGesture(start);
      await g.moveBy(const Offset(0, 20));
      await t.pump(const Duration(milliseconds: 16));
      var worstCards = 0;
      var worstRows = 0;
      var worstMs = 0.0;
      final stops = [
        d2.first.top - 30,
        for (final r in d2) r.center.dy + 4,
        d3Top + 4,
        d2.last.center.dy + 4,
      ];
      for (final y in stops) {
        final cards = _cards();
        final rows = _snapshot();
        await g.moveTo(start + Offset(0, y - rowCentre.dy));
        final sw = Stopwatch()..start();
        await t.pump(const Duration(milliseconds: 16));
        sw.stop();
        final changed = _cardsRebuilt(cards);
        if (changed > worstCards) worstCards = changed;
        final r = _rebuilt(rows).values.fold(0, (a, b) => a + b);
        if (r > worstRows) worstRows = r;
        if (sw.elapsedMicroseconds / 1000 > worstMs) worstMs = sw.elapsedMicroseconds / 1000;
      }
      expect(worstCards, lessThanOrEqualTo(2));
      expect(worstRows, 0);
      final s = t.state<TripSpotDragScopeState>(dragScope).drag.value;
      expect(s?.targetDay, 2);
      expect(s?.refused, isFalse);
      final sw = Stopwatch()..start();
      await g.up();
      await t.pump();
      sw.stop();
      expect(dayIds(c, 2).contains('L1d1s0'), isTrue);
      final r = _rebuilt(rowsBefore);
      expect(r.keys.where((d) => d != 1 && d != 2), isEmpty, reason: '$r');
      expect((r[1] ?? 0) + (r[2] ?? 0), lessThanOrEqualTo(perDay[0] + perDay[1]));
      _report.add('cross $name: target change worst $worstCards cards, $worstRows rows, worst move frame ${worstMs.toStringAsFixed(1)} ms; '
          'drop rebuilt day1 ${r[1] ?? 0} of ${perDay[0]}, day2 ${r[2] ?? 0} of ${perDay[1] + 1}, other days 0, drop frame ${(sw.elapsedMicroseconds / 1000).toStringAsFixed(1)} ms');
      await drainDrag(t);
    });
  }
}

Finder get _cardFinder => find.byKey(TripDaySpotList.dropKey);

Map<Element, Widget> _cards() => {for (final e in _cardFinder.evaluate()) e: e.widget};

int _cardsRebuilt(Map<Element, Widget> before) {
  var n = 0;
  for (final e in _cardFinder.evaluate()) {
    final old = before[e];
    if (old == null || !identical(old, e.widget)) n++;
  }
  return n;
}
