import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/widgets/drag/trip_spot_drag_scope.dart';
import 'package:bakhli/features/trip/widgets/trip_day_spot_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/drag_rig.dart';
import 'support/engine_rig.dart';

final _report = <String>[];

class _Rebuilds {
  final Map<String, int> byType = {};
  int get total => byType.values.fold(0, (a, b) => a + b);
  int of(String t) => byType[t] ?? 0;

  void start() {
    byType.clear();
    debugOnRebuildDirtyWidget = (e, _) {
      final n = e.widget.runtimeType.toString();
      byType[n] = (byType[n] ?? 0) + 1;
    };
  }

  void stop() => debugOnRebuildDirtyWidget = null;
}

Future<int> _framesToSettle(WidgetTester t) async {
  var frames = 0;
  while (t.binding.hasScheduledFrame && frames < 240) {
    await t.pump(const Duration(milliseconds: 16));
    frames++;
  }
  return frames;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    debugOnRebuildDirtyWidget = null;
    DS.debugReset();
    Get.reset();
  });
  tearDownAll(() => debugPrint('REVIEW2\n${_report.join('\n')}'));

  testWidgets('a touch on the same day while the drop settles does not lose the drop', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[5, 2]]));
    final h = rowHeight(t, 'L1d1s0');
    final g = await pressAndMove(t, t.getCenter(handleOf('L1d1s0')), h * 2.2, steps: 12);
    await g.up();
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));
    final g2 = await t.startGesture(t.getCenter(handleOf('L1d1s4')));
    await g2.moveBy(const Offset(0, 30));
    await t.pump(const Duration(milliseconds: 16));
    await g2.up();
    await settleDrop(t);
    await t.pump(const Duration(seconds: 1));
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s2', 'L1d1s0', 'L1d1s3', 'L1d1s4']);
    expect(pageBadgeTexts(t, 1), ['1', '2', '3', '4', '5']);

    final g3 = await pressAndMove(t, t.getCenter(handleOf('L1d1s4')), -h * 1.2, steps: 8);
    await g3.up();
    await settleDrop(t);
    await t.pump(const Duration(seconds: 1));
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s2', 'L1d1s0', 'L1d1s4', 'L1d1s3']);
    await drainDrag(t);
  });

  testWidgets('a swipe on a row while the drop settles does not lose the drop', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[5, 2]]));
    final h = rowHeight(t, 'L1d1s0');
    final g = await pressAndMove(t, t.getCenter(handleOf('L1d1s0')), h * 2.2, steps: 12);
    await g.up();
    await t.pump();
    await t.pump(const Duration(milliseconds: 16));
    final body = t.getCenter(find.descendant(of: row('L1d1s4'), matching: find.text('L1d1s4')));
    final g2 = await t.startGesture(body);
    await g2.moveBy(const Offset(0, -40));
    await t.pump(const Duration(milliseconds: 16));
    await g2.up();
    await settleDrop(t);
    await t.pump(const Duration(seconds: 1));
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s2', 'L1d1s0', 'L1d1s3', 'L1d1s4']);
    await drainDrag(t);
  });

  testWidgets('a second finger on another day during a drag starts nothing and the first drag still lands', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[4, 4]]));
    final h = rowHeight(t, 'L1d1s0');
    final a = await pressAndMove(t, t.getCenter(handleOf('L1d1s0')), h * 0.6, steps: 4);
    final b = await pressAndMove(t, t.getCenter(handleOf('L1d2s0')), h * 2.2, steps: 8);
    expect(t.state<TripSpotDragScopeState>(dragScope).drag.value?.day, 1);
    for (var i = 0; i < 6; i++) {
      await a.moveBy(Offset(0, h * 0.3));
      await t.pump(const Duration(milliseconds: 16));
    }
    await b.up();
    await t.pump();
    await a.up();
    await settleDrop(t);
    await t.pump(const Duration(seconds: 1));
    expect(dayIds(c, 2), ['L1d2s0', 'L1d2s1', 'L1d2s2', 'L1d2s3']);
    expect(dayIds(c, 1).first, isNot('L1d1s0'));
    expect(dayIds(c, 1).toSet(), {'L1d1s0', 'L1d1s1', 'L1d1s2', 'L1d1s3'});
    await drainDrag(t);
  });

  testWidgets('haptics are rate limited on a fast drag over many rows', (t) async {
    final calls = captureHaptics(t);
    final c = await pumpDragPlan(t, enginePlan([[30]]), size: const Size(360, 3200));
    final h = rowHeight(t, 'L1d1s0');
    final g = await pressAndMove(t, t.getCenter(handleOf('L1d1s0')), h * 12.2, steps: 6);
    final s = t.state<TripSpotDragScopeState>(dragScope).drag.value;
    expect(s?.slot, greaterThanOrEqualTo(8));
    final clicks = calls.where((x) => x == selectionClick).length;
    expect(clicks, lessThanOrEqualTo(3), reason: '$calls');
    expect(clicks, greaterThanOrEqualTo(2));
    _report.add('haptics 1x30 fast drag over ${s?.slot} slots in 6 frames: $clicks clicks (lift included)');
    await g.up();
    await settleDrop(t);
    expect(calls.where((x) => x == lightImpact).length, 1);
    expect(dayIds(c, 1).indexOf('L1d1s0'), greaterThanOrEqualTo(8));
    await drainDrag(t);
  });

  for (final approved in [false, true]) {
    testWidgets('text scale 1.3 at 320 dp: rows do not overflow, handle stays 44 dp (approved scale $approved)', (t) async {
      if (approved) DS.applyApproved();
      await pumpDragPlan(t, enginePlan([[6, 6]]), size: const Size(320, 2600), textScale: 1.3);
      expect(t.takeException(), isNull);
      for (final id in ['L1d1s0', 'L1d1s5', 'L1d2s3']) {
        final hit = t.getRect(handleOf(id));
        expect(hit.width, greaterThanOrEqualTo(44));
        expect(hit.height, greaterThanOrEqualTo(44));
        expect(t.getRect(row(id)).right, lessThanOrEqualTo(320));
      }
      final g = await pressAndMove(t, t.getCenter(handleOf('L1d1s0')), rowHeight(t, 'L1d1s0') * 1.2, steps: 8);
      await t.pump(const Duration(milliseconds: 300));
      expect(t.takeException(), isNull);
      await g.up();
      await settleDrop(t);
      expect(t.takeException(), isNull);
      await drainDrag(t);
    });
  }

  final fixtures = <String, List<int>>{
    '3x12': [12, 12, 12],
    '1x30': [30],
    '3x12+1x30': [12, 12, 12, 30],
  };
  for (final MapEntry(key: name, value: perDay) in fixtures.entries) {
    testWidgets('frame budget: rebuilds per move frame, per slot change, drop-to-settled frames ($name)', (t) async {
      final c = await pumpDragPlan(t, enginePlan([perDay]), size: const Size(360, 3200));
      final rows = perDay.fold(0, (a, b) => a + b);
      final h = rowHeight(t, 'L1d1s0');
      final r = _Rebuilds();
      final g = await pressAndMove(t, t.getCenter(handleOf('L1d1s0')), h * 0.45, steps: 3);
      await t.pump(const Duration(milliseconds: 300));
      expect(t.state<TripSpotDragScopeState>(dragScope).drag.value, isNotNull);
      var worstMove = 0;
      var worstSlot = 0;
      var badgesSlot = 0;
      var cardsMove = 0;
      for (var i = 0; i < 10; i++) {
        final before = t.state<TripSpotDragScopeState>(dragScope).drag.value?.slot;
        r.start();
        await g.moveBy(Offset(0, h * 0.27));
        await t.pump(const Duration(milliseconds: 16));
        r.stop();
        final after = t.state<TripSpotDragScopeState>(dragScope).drag.value?.slot;
        final k = r.of('TripDaySpotList') + r.of('_DaySpots') + r.of('_StopItem');
        cardsMove += k;
        if (before == after) {
          if (r.total > worstMove) worstMove = r.total;
        } else {
          if (r.total > worstSlot) worstSlot = r.total;
          final b = r.of('_StopBadge');
          if (b > badgesSlot) badgesSlot = b;
        }
      }
      expect(cardsMove, 0, reason: 'no day card, day list or row rebuild while moving');
      expect(badgesSlot, lessThanOrEqualTo(3), reason: 'only badges whose number changes rebuild');
      r.start();
      await g.up();
      var landed = 0;
      while (proxyRows.evaluate().isNotEmpty && landed < 60) {
        await t.pump(const Duration(milliseconds: 16));
        landed++;
      }
      final atLand = r.total;
      final settle = landed + await _framesToSettle(t);
      r.stop();
      expect(dayIds(c, 1).first, isNot('L1d1s0'));
      expect(landed, lessThanOrEqualTo(20));
      expect(settle, lessThan(40));
      _report.add('$name: elements rebuilt per move frame (no slot change) worst $worstMove, per slot change worst $worstSlot '
          '(badge builders $badgesSlot of $rows rows), day cards/lists/rows rebuilt while moving $cardsMove, '
          'drop-to-landed $landed frames (elements rebuilt $atLand), drop-to-idle incl. snackbar $settle frames, rebuilt during settle ${r.total} (rows ${r.of('_StopItem')}, day cards ${r.of('TripDaySpotList')})');
      await drainDrag(t);
    });
  }

  testWidgets('day card registers as drop target only in edit mode', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[3, 3]]), edit: false);
    expect(find.byKey(TripDaySpotList.dropHighlightKey), findsNothing);
    c.editMode.value = true;
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byKey(TripDaySpotList.handleKey), findsNWidgets(6));
    await drainDrag(t);
  });
}
