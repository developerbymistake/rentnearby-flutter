import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/features/trip/models/trip_plan_result_model.dart';
import 'package:bakhli/features/trip/trip_strings_v2_plan.dart';
import 'package:bakhli/features/trip/trip_strings_wizard.dart';
import 'package:bakhli/features/trip/utils/trip_format.dart';
import 'package:bakhli/features/trip/widgets/drag/trip_spot_drag_start.dart';
import 'package:bakhli/features/trip/widgets/trip_day_spot_list.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/drag_rig.dart';
import 'support/engine_rig.dart';

TripPlanResult _result(List<(String, String, int)> legs) => TripPlanResult(
      days: [
        TripPlanDay(
          day: 1,
          spotIds: const [],
          visitMinutes: 0,
          driveMinutes: 0,
          totalMinutes: 0,
          km: 0,
          overLimit: false,
          isEstimate: false,
          legs: [for (final (a, b, m) in legs) TripLeg(fromId: a, toId: b, minutes: m, km: 1, isEstimate: false)],
        ),
      ],
      warnings: const [],
      osrmAvailable: true,
      dayLimitMinutes: 300,
    );

Future<void> _dragHandle(WidgetTester t, String id, double rows, {int steps = 12}) async {
  final g = await pressAndMove(t, t.getCenter(handleOf(id)), rowHeight(t, id) * rows, steps: steps);
  await g.up();
  await settleDrop(t);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    DS.debugReset();
    Get.reset();
  });

  testWidgets('handle: 44 dp touch area at 80% scale, icon and row unchanged', (t) async {
    DS.debugSet(size: 0.80);
    await pumpDragPlan(t, enginePlan([[3, 2]]));
    final hit = t.getRect(handleOf('L1d1s0'));
    expect(hit.width, greaterThanOrEqualTo(44));
    expect(hit.height, greaterThanOrEqualTo(44));
    final r = t.getRect(row('L1d1s0'));
    final icon = t.getRect(find.descendant(of: row('L1d1s0'), matching: find.byIcon(Icons.drag_indicator_rounded)));
    expect(icon.width, closeTo(DS.s(20), 0.01));
    expect(icon.height, closeTo(DS.s(20), 0.01));
    expect(icon.left - r.left, closeTo(DS.s(12), 0.01));
    expect(hit.contains(icon.center), isTrue);
    expect(hit.left, r.left);
    await drainDrag(t);
  });

  testWidgets('immediate handle drag reorders without a wait and keeps the page still', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[4, 2]]));
    final before = pageOffset(t);
    await _dragHandle(t, 'L1d1s0', 2.2);
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s2', 'L1d1s0', 'L1d1s3']);
    expect(pageOffset(t), before);
    await drainDrag(t);
  });

  testWidgets('long press on the row body drags', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[4, 2]]));
    final body = t.getCenter(find.descendant(of: row('L1d1s0'), matching: find.text('L1d1s0')));
    final g = await pressAndMove(t, body, rowHeight(t, 'L1d1s0') * 1.2, hold: const Duration(milliseconds: 320));
    await g.up();
    await settleDrop(t);
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s0', 'L1d1s2', 'L1d1s3']);
    await drainDrag(t);
  });

  testWidgets('a quick swipe on the row body scrolls the page and does not reorder', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[4, 2], [3]]), size: const Size(360, 700));
    await t.ensureVisible(row('L1d1s2'));
    await t.pump(const Duration(milliseconds: 300));
    final before = pageOffset(t);
    await t.dragFrom(t.getCenter(find.descendant(of: row('L1d1s2'), matching: find.text('L1d1s2'))), const Offset(0, -200));
    await t.pump(const Duration(milliseconds: 300));
    expect(pageOffset(t), greaterThan(before));
    expect(dayIds(c, 1), ['L1d1s0', 'L1d1s1', 'L1d1s2', 'L1d1s3']);
    await drainDrag(t);
  });

  testWidgets('taps still open the place menu and remove still removes', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[3, 2]]), reduceMotion: true);
    await t.tap(find.descendant(of: row('L1d1s1'), matching: find.text('L1d1s1')));
    await t.pumpAndSettle();
    expect(find.text(TripStringsWizard.replacePlace), findsOneWidget);
    Navigator.of(t.element(find.text(TripStringsWizard.replacePlace))).pop();
    await t.pumpAndSettle();
    await t.tapAt(t.getCenter(handleOf('L1d1s1')));
    await t.pumpAndSettle();
    expect(find.text(TripStringsWizard.replacePlace), findsOneWidget);
    Navigator.of(t.element(find.text(TripStringsWizard.replacePlace))).pop();
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: row('L1d1s2'), matching: find.byTooltip(TripStringsV2Plan.removePlace)));
    await t.pump();
    expect(dayIds(c, 1), ['L1d1s0', 'L1d1s1']);
    await drainDrag(t);
  });

  testWidgets('edit mode only; long press on the card enters edit mode', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[3, 2]]), edit: false, reduceMotion: true);
    expect(find.byType(TripSpotDragStart), findsNothing);
    expect(find.byType(ReorderableList), findsNothing);
    await t.longPress(find.byKey(TripDaySpotList.headerKey).first);
    await t.pump();
    expect(c.editMode.value, isTrue);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(TripSpotDragStart), findsWidgets);
    await drainDrag(t);
  });

  testWidgets('locked plan and past day: no handle, nothing to drag', (t) async {
    await pumpDragPlan(t, enginePlan([[3, 2]]), lock: lockedByRequest, reduceMotion: true);
    expect(find.byType(TripSpotDragStart), findsNothing);
    expect(find.byKey(TripDaySpotList.handleKey), findsNothing);
    await drainDrag(t);
  });

  testWidgets('past day has no drag start, a later day has', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[2, 2, 2]], start: daysFromToday(-1)), reduceMotion: true);
    expect(find.descendant(of: find.byKey(const ValueKey('trip-day-1')), matching: find.byType(TripSpotDragStart)), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('trip-day-3')), matching: find.byType(TripSpotDragStart)), findsWidgets);
    final before = dayIds(c, 1);
    final g = await pressAndMove(t, t.getCenter(row('L1d1s0')), 120, hold: const Duration(milliseconds: 400));
    await g.up();
    await settleDrop(t);
    expect(dayIds(c, 1), before);
    await drainDrag(t);
  });

  testWidgets('haptics: click at lift, one per slot, impact only at a changing drop', (t) async {
    final calls = captureHaptics(t);
    await pumpDragPlan(t, enginePlan([[4, 2]]));
    final h = rowHeight(t, 'L1d1s0');
    var g = await pressAndMove(t, t.getCenter(handleOf('L1d1s0')), h * 2.2, steps: 22);
    expect(calls, [selectionClick, selectionClick, selectionClick]);
    await g.up();
    await settleDrop(t);
    expect(calls.where((x) => x == lightImpact).length, 1);
    await t.pump(const Duration(seconds: 6));

    calls.clear();
    g = await pressAndMove(t, t.getCenter(handleOf('L1d1s1')), h * 0.4, steps: 4);
    await g.up();
    await settleDrop(t);
    expect(calls, [selectionClick]);
    await drainDrag(t);
  });

  testWidgets('lifted card: scaled, card shadow, same text styles', (t) async {
    await pumpDragPlan(t, enginePlan([[4, 2]]));
    final g = await pressAndMove(t, t.getCenter(handleOf('L1d1s0')), 30, steps: 3);
    await t.pump(const Duration(milliseconds: 300));
    expect(proxyRows, findsOneWidget);
    final scales = [
      for (final e in find.ancestor(of: proxyRows, matching: find.byType(Transform)).evaluate())
        (e.widget as Transform).transform.getMaxScaleOnAxis(),
    ];
    expect(scales.any((s) => s > 1.0), isTrue);
    final boxes = find.ancestor(of: proxyRows, matching: find.byType(DecoratedBox)).evaluate().map((e) => (e.widget as DecoratedBox).decoration);
    expect(boxes.whereType<BoxDecoration>().any((d) => listEquals(d.boxShadow, DS.shadows(TripLook.dayCardShadow))), isTrue);
    final name = t.widget<Text>(find.descendant(of: proxyRows, matching: find.text('L1d1s0')));
    final other = t.widget<Text>(find.descendant(of: row('L1d1s1'), matching: find.text('L1d1s1')));
    expect(name.style, other.style);
    await g.up();
    await settleDrop(t);
    await drainDrag(t);
  });

  testWidgets('live numbers while dragging', (t) async {
    await pumpDragPlan(t, enginePlan([[4, 2]]));
    expect(pageBadgeTexts(t, 1), ['1', '2', '3', '4']);
    final g = await pressAndMove(t, t.getCenter(handleOf('L1d1s0')), rowHeight(t, 'L1d1s0') * 2.2, steps: 12);
    await t.pump(const Duration(milliseconds: 300));
    expect(pageBadgeTexts(t, 1), ['1', '2', '4']);
    expect(proxyBadgeTexts(), ['3']);
    await g.up();
    await settleDrop(t);
    expect(pageBadgeTexts(t, 1), ['1', '2', '3', '4']);
    await drainDrag(t);
  });

  testWidgets('slot parity with the SDK for five distances', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[6, 2]]), reduceMotion: true);
    final h = rowHeight(t, 'L1d1s0');
    for (final rows in [0.3, 0.7, 1.4, 2.6, 4.3]) {
      c.plan.value = enginePlan([[6, 2]]);
      await t.pump(const Duration(milliseconds: 50));
      final g = await pressAndMove(t, t.getCenter(handleOf('L1d1s1')), h * rows, steps: 9);
      final shown = int.parse(proxyBadgeTexts().single) - 1;
      await g.up();
      await t.pump();
      expect(dayIds(c, 1).indexOf('L1d1s1'), shown, reason: 'rows $rows');
      await t.pump(const Duration(milliseconds: 100));
    }
    await drainDrag(t);
  });

  testWidgets('undo restores the exact order; a second edit replaces the snackbar', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[4, 2]]), reduceMotion: true);
    await _dragHandle(t, 'L1d1s0', 2.2);
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s2', 'L1d1s0', 'L1d1s3']);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text(TripStringsV2Plan.orderChanged), findsOneWidget);
    await t.tap(find.text(TripStringsV2Plan.undo));
    await t.pump();
    expect(dayIds(c, 1), ['L1d1s0', 'L1d1s1', 'L1d1s2', 'L1d1s3']);
    await t.pump(const Duration(seconds: 6));

    await _dragHandle(t, 'L1d1s3', -1.2);
    await t.pump(const Duration(milliseconds: 500));
    await _dragHandle(t, 'L1d1s0', 1.2);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text(TripStringsV2Plan.orderChanged), findsOneWidget);
    await drainDrag(t);
  });

  testWidgets('times: new pair blank, unchanged pair keeps its minutes, result fills all', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[3, 2]]), reduceMotion: true);
    c.result.value = _result([('L1d1s0', 'L1d1s1', 17), ('L1d1s1', 'L1d1s2', 23)]);
    await t.pump();
    final day1 = find.byKey(const ValueKey('trip-day-1'));
    expect(find.descendant(of: day1, matching: find.text(TripFormat.duration(17))), findsOneWidget);
    expect(find.descendant(of: day1, matching: find.text(TripFormat.duration(23))), findsOneWidget);
    await _dragHandle(t, 'L1d1s0', 2.2);
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s2', 'L1d1s0']);
    expect(find.descendant(of: day1, matching: find.text(TripFormat.duration(23))), findsOneWidget);
    expect(find.descendant(of: day1, matching: find.text(TripFormat.duration(17))), findsNothing);
    c.result.value = _result([('L1d1s1', 'L1d1s2', 23), ('L1d1s2', 'L1d1s0', 31)]);
    await t.pump();
    expect(find.descendant(of: day1, matching: find.text(TripFormat.duration(31))), findsOneWidget);
    await drainDrag(t);
  });

  testWidgets('semantics: move up and down, handle label, undo snackbar', (t) async {
    final sem = t.ensureSemantics();
    final c = await pumpDragPlan(t, enginePlan([[3, 2]]), reduceMotion: true);
    Map<String, int> actions(String id) {
      final data = t.getSemantics(row(id)).getSemanticsData();
      return {for (final a in data.customSemanticsActionIds ?? const <int>[]) CustomSemanticsAction.getAction(a)!.label!: a};
    }

    expect(actions('L1d1s0').containsKey(TripStringsV2Plan.moveUp), isFalse);
    expect(actions('L1d1s0').containsKey(TripStringsV2Plan.moveDown), isTrue);
    expect(actions('L1d1s2').containsKey(TripStringsV2Plan.moveDown), isFalse);
    expect(actions('L1d1s1').keys, containsAll([TripStringsV2Plan.moveUp, TripStringsV2Plan.moveDown]));
    expect(find.bySemanticsLabel(RegExp(TripStringsV2Plan.dragHandle)), findsWidgets);
    final node = t.getSemantics(row('L1d1s1'));
    node.owner!.performAction(node.id, SemanticsAction.customAction, actions('L1d1s1')[TripStringsV2Plan.moveUp]);
    await t.pump();
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s0', 'L1d1s2']);
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text(TripStringsV2Plan.orderChanged), findsOneWidget);
    sem.dispose();
    await drainDrag(t);
  });

  testWidgets('reduced motion: no lift scale, order changes in the release frame', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[4, 2]]), reduceMotion: true);
    final g = await pressAndMove(t, t.getCenter(handleOf('L1d1s0')), rowHeight(t, 'L1d1s0') * 2.2, steps: 12);
    await t.pump(const Duration(milliseconds: 300));
    final scales = [
      for (final e in find.ancestor(of: proxyRows, matching: find.byType(Transform)).evaluate())
        (e.widget as Transform).transform.getMaxScaleOnAxis(),
    ];
    expect(scales.every((s) => s == 1.0), isTrue);
    await g.up();
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s2', 'L1d1s0', 'L1d1s3']);
    await t.pump();
    expect(proxyRows, findsNothing);
    await drainDrag(t);
  });

  testWidgets('auto-scroll: holding at the bottom edge scrolls the page and the gap follows', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[6, 6], [3]]), size: const Size(360, 640));
    await t.ensureVisible(row('L1d1s0'));
    await t.pump(const Duration(milliseconds: 300));
    final before = pageOffset(t);
    final start = t.getCenter(handleOf('L1d1s0'));
    final g = await t.startGesture(start);
    final bottom = t.getSize(find.byType(MaterialApp)).height - 30;
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset(start.dx, start.dy + (bottom - start.dy) * i / 10));
      await t.pump(const Duration(milliseconds: 16));
    }
    // Stop while the lifted card is still over day 1; past it the drop belongs to day 2 (cross-day).
    for (var i = 0; i < 40 && pageOffset(t) <= before + 50; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(pageOffset(t), greaterThan(before + 50));
    final shown = int.parse(proxyBadgeTexts().single);
    await g.up();
    await settleDrop(t);
    expect(dayIds(c, 1).indexOf('L1d1s0'), shown - 1);
    expect(shown, greaterThan(1));
    await drainDrag(t);
  });
}
