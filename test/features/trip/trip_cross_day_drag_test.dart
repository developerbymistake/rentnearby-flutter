import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/features/trip/trip_constants.dart';
import 'package:bakhli/features/trip/trip_strings_mca_a1.dart';
import 'package:bakhli/features/trip/trip_strings_v2_plan.dart';
import 'package:bakhli/features/trip/widgets/drag/trip_spot_drag_scope.dart';
import 'package:bakhli/features/trip/widgets/trip_day_spot_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

import 'support/drag_rig.dart';
import 'support/engine_rig.dart';

Finder dayCard(int d) => find.byKey(ValueKey('trip-day-$d'));

Finder highlightOn(int d) => find.descendant(of: dayCard(d), matching: find.byKey(TripDaySpotList.dropHighlightKey));

Finder lineOn(int d) => find.descendant(of: dayCard(d), matching: find.byKey(TripDaySpotList.dropLineKey));

Finder get anyHighlight => find.byKey(TripDaySpotList.dropHighlightKey);

TripDragState? dragState(WidgetTester t) => t.state<TripSpotDragScopeState>(dragScope).drag.value;

Rect dropCard(WidgetTester t, int d) => t.getRect(find.descendant(of: dayCard(d), matching: find.byKey(TripDaySpotList.dropKey)));

// Moves the finger so the centre of the lifted card ends on [target].
Future<TestGesture> liftTo(WidgetTester t, String id, Offset target, {int steps = 12}) async {
  final start = t.getCenter(handleOf(id));
  final delta = target - t.getCenter(row(id));
  final g = await t.startGesture(start);
  for (var i = 1; i <= steps; i++) {
    await g.moveTo(start + delta * (i / steps));
    await t.pump(const Duration(milliseconds: 16));
  }
  return g;
}

Offset betweenRows(WidgetTester t, String source, String upper) =>
    Offset(t.getCenter(row(source)).dx, t.getRect(row(upper)).bottom);

Offset cardMiddle(WidgetTester t, String source, int day) => Offset(t.getCenter(row(source)).dx, dropCard(t, day).center.dy);

Future<void> showSnack(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 500));
}

Map<String, int> actions(WidgetTester t, String id) {
  final data = t.getSemantics(row(id)).getSemanticsData();
  return {for (final a in data.customSemanticsActionIds ?? const <int>[]) CustomSemanticsAction.getAction(a)!.label!: a};
}

void perform(WidgetTester t, String id, String label) {
  final node = t.getSemantics(row(id));
  node.owner!.performAction(node.id, SemanticsAction.customAction, actions(t, id)[label]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(toastification.managers.clear);
  tearDown(Get.reset);

  for (final reduce in [false, true]) {
    testWidgets('drop between rows 1 and 2 of day 2 lands at index 1 in the release frame (reduced motion $reduce)', (t) async {
      final c = await pumpDragPlan(t, enginePlan([[3, 3]]), reduceMotion: reduce);
      final g = await liftTo(t, 'L1d1s0', betweenRows(t, 'L1d1s0', 'L1d2s0'));
      expect(dragState(t)?.targetDay, 2);
      expect(dragState(t)?.targetIndex, 1);
      await g.up();
      expect(dayIds(c, 1), ['L1d1s1', 'L1d1s2']);
      expect(dayIds(c, 2), ['L1d2s0', 'L1d1s0', 'L1d2s1', 'L1d2s2']);
      await t.pump();
      expect(proxyRows, findsNothing);
      expect(anyHighlight, findsNothing);
      await drainDrag(t);
    });
  }

  testWidgets('highlight and drop line only on the hovered day, no layout shift', (t) async {
    await pumpDragPlan(t, enginePlan([[3, 3, 3]]));
    final rects = [for (final id in ['L1d2s0', 'L1d2s1', 'L1d2s2']) t.getRect(row(id))];
    final target = betweenRows(t, 'L1d1s0', 'L1d2s0');
    final home = t.getCenter(handleOf('L1d1s0'));
    final g = await liftTo(t, 'L1d1s0', target);
    expect(highlightOn(2), findsOneWidget);
    expect(lineOn(2), findsOneWidget);
    expect(highlightOn(1), findsNothing);
    expect(highlightOn(3), findsNothing);
    expect(t.getRect(lineOn(2)).center.dy, closeTo(rects[0].bottom, 1));
    expect([for (final id in ['L1d2s0', 'L1d2s1', 'L1d2s2']) t.getRect(row(id))], rects);
    final border = (t.widget<DecoratedBox>(highlightOn(2)).decoration as BoxDecoration).border! as Border;
    expect(border.top.color, isNot(TripLook.error));

    await g.moveTo(home + const Offset(0, 1));
    await t.pump(const Duration(milliseconds: 16));
    expect(anyHighlight, findsNothing);
    expect(find.byKey(TripDaySpotList.dropLineKey), findsNothing);
    await g.up();
    await settleDrop(t);
    await drainDrag(t);
  });

  testWidgets('empty day and rest day take the drop at 0; undo gives the rest flag back', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[2, 0, 0]], restDays: {3}));
    var g = await liftTo(t, 'L1d1s0', cardMiddle(t, 'L1d1s0', 2));
    expect(dragState(t)?.targetDay, 2);
    expect(lineOn(2), findsOneWidget);
    await g.up();
    expect(dayIds(c, 2), ['L1d1s0']);

    // Let the re-plan after the first drop finish; it changes the content above the days.
    await t.pump(const Duration(seconds: 2));
    g = await liftTo(t, 'L1d1s1', cardMiddle(t, 'L1d1s1', 3));
    expect(dragState(t)?.targetDay, 3);
    expect(lineOn(3), findsOneWidget);
    await g.up();
    expect(dayIds(c, 3), ['L1d1s1']);
    expect(c.plan.value!.dayAt(3)!.restDay, isFalse);
    expect(c.plan.value!.dayAt(1)!.spots, isEmpty);
    expect(c.plan.value!.days.length, 3);
    await showSnack(t);
    await t.tap(find.text(TripStringsV2Plan.undo).last);
    await t.pump();
    expect(dayIds(c, 1), ['L1d1s1']);
    expect(c.plan.value!.dayAt(3)!.spots, isEmpty);
    expect(c.plan.value!.dayAt(3)!.restDay, isTrue);
    await drainDrag(t);
  });

  testWidgets('full day: refused look, nothing changes, day full toast', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[2, 6]]), toasts: true);
    final before = c.plan.value;
    final shown = find.text(TripStringsV2Plan.dayFull).evaluate().length;
    final g = await liftTo(t, 'L1d1s0', cardMiddle(t, 'L1d1s0', 2));
    expect(dragState(t)?.refused, isTrue);
    expect(highlightOn(2), findsOneWidget);
    expect(lineOn(2), findsNothing);
    final border = (t.widget<DecoratedBox>(highlightOn(2)).decoration as BoxDecoration).border! as Border;
    expect(border.top.color, TripLook.error);
    await g.up();
    expect(identical(c.plan.value, before), isTrue);
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(TripStringsV2Plan.dayFull).evaluate().length, shown + 1);
    expect(find.byType(SnackBar), findsNothing);
    await drainDrag(t);
  });

  testWidgets('day of another city: no highlight, nothing changes, different city toast', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[2], [2]]), toasts: true);
    final before = c.plan.value;
    final g = await liftTo(t, 'L1d1s0', cardMiddle(t, 'L1d1s0', 2));
    expect(dragState(t)?.foreign, isTrue);
    expect(anyHighlight, findsNothing);
    await g.up();
    expect(identical(c.plan.value, before), isTrue);
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(find.text(TripStringsMcaA1.differentCity), findsOneWidget);
    await drainDrag(t);
  });

  testWidgets('release outside any day: nothing changes, no toast, no snackbar', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[3, 3]]), toasts: true);
    final before = c.plan.value;
    final g = await liftTo(t, 'L1d1s0', Offset(t.getCenter(row('L1d1s0')).dx, 4));
    expect(anyHighlight, findsNothing);
    await g.up();
    expect(identical(c.plan.value, before), isTrue);
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(proxyRows, findsNothing);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text(TripStringsV2Plan.dayFull), findsNothing);
    expect(find.text(TripStringsMcaA1.differentCity), findsNothing);
    await drainDrag(t);
  });

  testWidgets('undo snackbar Moved to Day 2 restores both days exactly', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[3, 3]]));
    final d1 = dayIds(c, 1);
    final d2 = dayIds(c, 2);
    final g = await liftTo(t, 'L1d1s1', betweenRows(t, 'L1d1s1', 'L1d2s1'));
    await g.up();
    expect(dayIds(c, 2), ['L1d2s0', 'L1d2s1', 'L1d1s1', 'L1d2s2']);
    await showSnack(t);
    expect(find.text(TripStringsV2Plan.movedToDay(2)), findsOneWidget);
    await t.tap(find.text(TripStringsV2Plan.undo).last);
    await t.pump();
    expect(dayIds(c, 1), d1);
    expect(dayIds(c, 2), d2);
    await drainDrag(t);
  });

  testWidgets('haptics: click at lift, on entering the day, per new slot, light impact at the drop', (t) async {
    final calls = captureHaptics(t);
    final c = await pumpDragPlan(t, enginePlan([[3, 3]]));
    final above = Offset(t.getCenter(row('L1d1s0')).dx, t.getRect(row('L1d2s0')).top + 2);
    final g = await liftTo(t, 'L1d1s0', above);
    expect(calls.first, selectionClick);
    expect(dragState(t)?.targetDay, 2);
    expect(dragState(t)?.targetIndex, 0);
    final atEntry = calls.length;
    await t.pump(TripConstants.dragHapticGap);
    await g.moveBy(Offset(0, t.getRect(row('L1d2s0')).height));
    await t.pump(const Duration(milliseconds: 16));
    expect(dragState(t)?.targetIndex, 1);
    expect(calls.length, atEntry + 1);
    expect(calls.last, selectionClick);
    await g.up();
    expect(calls.last, lightImpact);
    expect(calls.where((x) => x == lightImpact).length, 1);
    expect(dayIds(c, 2)[1], 'L1d1s0');
    await drainDrag(t);
  });

  testWidgets('haptics: entering a day clicks once', (t) async {
    final calls = captureHaptics(t);
    await pumpDragPlan(t, enginePlan([[3, 3]]));
    final home = t.getCenter(handleOf('L1d1s0'));
    final g = await liftTo(t, 'L1d1s0', Offset(t.getCenter(row('L1d1s0')).dx, dropCard(t, 1).bottom - 2), steps: 6);
    expect(dragState(t)?.targetDay, isNull);
    final before = calls.length;
    await g.moveBy(Offset(0, dropCard(t, 2).top - dropCard(t, 1).bottom + 20));
    await t.pump(const Duration(milliseconds: 16));
    expect(dragState(t)?.targetDay, 2);
    expect(calls.length, before + 1);
    await g.moveTo(home);
    await t.pump(const Duration(milliseconds: 16));
    await g.up();
    await settleDrop(t);
    await drainDrag(t);
  });

  testWidgets('auto-scroll: day 3 off screen, hold at the bottom edge, drop lands on day 3', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[3, 3, 3]]), size: const Size(360, 640));
    await t.ensureVisible(row('L1d1s0'));
    await t.pump(const Duration(milliseconds: 300));
    expect(dropCard(t, 3).top, greaterThan(t.getSize(find.byType(MaterialApp)).height));
    final before = pageOffset(t);
    final start = t.getCenter(handleOf('L1d1s0'));
    final g = await t.startGesture(start);
    final bottom = t.getSize(find.byType(MaterialApp)).height - 24;
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset(start.dx, start.dy + (bottom - start.dy) * i / 10));
      await t.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < 200 && dragState(t)?.targetDay != 3; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(pageOffset(t), greaterThan(before + 100));
    expect(dragState(t)?.targetDay, 3);
    final index = dragState(t)!.targetIndex;
    await g.up();
    expect(dayIds(c, 3).indexOf('L1d1s0'), index);
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s2']);
    await drainDrag(t);
  });

  testWidgets('semantics: move to next day puts it on top, previous day at the end; absent for another city', (t) async {
    final sem = t.ensureSemantics();
    final c = await pumpDragPlan(t, enginePlan([[2, 2], [2]]), reduceMotion: true);
    expect(actions(t, 'L1d1s0').containsKey(TripStringsV2Plan.moveToPreviousDay), isFalse);
    expect(actions(t, 'L1d1s0').containsKey(TripStringsV2Plan.moveToNextDay), isTrue);
    expect(actions(t, 'L1d2s0').containsKey(TripStringsV2Plan.moveToPreviousDay), isTrue);
    expect(actions(t, 'L1d2s0').containsKey(TripStringsV2Plan.moveToNextDay), isFalse);

    perform(t, 'L1d1s1', TripStringsV2Plan.moveToNextDay);
    await showSnack(t);
    expect(dayIds(c, 2), ['L1d1s1', 'L1d2s0', 'L1d2s1']);
    expect(find.text(TripStringsV2Plan.movedToDay(2)), findsOneWidget);

    perform(t, 'L1d2s1', TripStringsV2Plan.moveToPreviousDay);
    await showSnack(t);
    expect(dayIds(c, 1), ['L1d1s0', 'L1d2s1']);
    expect(find.text(TripStringsV2Plan.movedToDay(1)), findsOneWidget);
    sem.dispose();
    await drainDrag(t);
  });

  testWidgets('semantics: no previous day action next to a past day', (t) async {
    final sem = t.ensureSemantics();
    await pumpDragPlan(t, enginePlan([[2, 2, 2]], start: daysFromToday(-1)));
    expect(actions(t, 'L1d2s0').containsKey(TripStringsV2Plan.moveToPreviousDay), isFalse);
    expect(actions(t, 'L1d2s0').containsKey(TripStringsV2Plan.moveToNextDay), isTrue);
    sem.dispose();
    await drainDrag(t);
  });

  testWidgets('locked plan and past source day: nothing to drag', (t) async {
    await pumpDragPlan(t, enginePlan([[2, 2]]), lock: lockedByRequest);
    expect(find.byKey(TripDaySpotList.handleKey), findsNothing);
    await drainDrag(t);
    Get.reset();

    final c = await pumpDragPlan(t, enginePlan([[2, 2]], start: daysFromToday(-1)));
    expect(handleOf('L1d1s0'), findsNothing);
    expect(handleOf('L1d2s0'), findsOneWidget);
    final before = c.plan.value;
    final g = await t.startGesture(t.getCenter(row('L1d1s0')));
    await t.pump(const Duration(milliseconds: 400));
    await g.moveBy(Offset(0, dropCard(t, 2).center.dy - t.getCenter(row('L1d1s0')).dy));
    await t.pump(const Duration(milliseconds: 16));
    await g.up();
    await t.pump();
    expect(identical(c.plan.value, before), isTrue);
    await drainDrag(t);
  });
}
