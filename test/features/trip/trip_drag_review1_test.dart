import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/models/trip_plan_result_model.dart';
import 'package:bakhli/features/trip/trip_strings_v2_plan.dart';
import 'package:bakhli/features/trip/widgets/drag/trip_spot_drag_scope.dart';
import 'package:bakhli/features/trip/widgets/trip_day_spot_list.dart';
import 'package:bakhli/features/trip/widgets/trip_leg_header.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/drag_rig.dart';
import 'support/engine_rig.dart';

TripDragState? _state(WidgetTester t) => t.state<TripSpotDragScopeState>(dragScope).drag.value;

Future<TestGesture> _lift(WidgetTester t, String id, double rows) =>
    pressAndMove(t, t.getCenter(handleOf(id)), rowHeight(t, id) * rows, steps: 12);

Future<void> _dragHandle(WidgetTester t, String id, double rows) async {
  final g = await _lift(t, id, rows);
  await g.up();
  await settleDrop(t);
}

void _expectIdle(WidgetTester t) {
  expect(_state(t), isNull);
  expect(proxyRows, findsNothing);
  expect(find.byKey(TripDaySpotList.dropHighlightKey), findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    DS.debugReset();
    Get.reset();
  });

  testWidgets('a place removed while another is dragged ends the drag cleanly and the next drag works', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[4, 2]]));
    final g = await _lift(t, 'L1d1s0', 1.2);
    c.removeSpot('L1d1s3', keepEmptyDays: true);
    await t.pump();
    await t.pump();
    await g.up();
    await settleDrop(t);
    expect(dayIds(c, 1), ['L1d1s0', 'L1d1s1', 'L1d1s2']);
    _expectIdle(t);
    expect(pageBadgeTexts(t, 1), ['1', '2', '3']);
    await t.pump(const Duration(seconds: 1));
    await _dragHandle(t, 'L1d1s0', 1.2);
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s0', 'L1d1s2']);
    await drainDrag(t);
  });

  testWidgets('an order change under a held drag never moves a different place', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[4, 2]]));
    final g = await _lift(t, 'L1d1s0', 1.2);
    expect(c.reorderTo(1, 0, 3), isTrue);
    await t.pump();
    await t.pump();
    await g.up();
    await settleDrop(t);
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s2', 'L1d1s3', 'L1d1s0']);
    _expectIdle(t);
    expect(pageBadgeTexts(t, 1), ['1', '2', '3', '4']);
    await drainDrag(t);
  });

  testWidgets('an order change while the drop settles never moves a different place', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[4, 2]]));
    final g = await _lift(t, 'L1d1s0', 1.2);
    await g.up();
    await t.pump();
    await t.pump(const Duration(milliseconds: 32));
    expect(c.reorderTo(1, 0, 3), isTrue);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s2', 'L1d1s3', 'L1d1s0']);
    _expectIdle(t);
    expect(pageBadgeTexts(t, 1), ['1', '2', '3', '4']);
    await drainDrag(t);
  });

  testWidgets('leaving edit mode while the drop settles keeps the new order and the right numbers', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[4, 2]]));
    final g = await _lift(t, 'L1d1s0', 1.2);
    await g.up();
    await t.pump();
    await t.pump(const Duration(milliseconds: 32));
    c.editMode.value = false;
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s0', 'L1d1s2', 'L1d1s3']);
    _expectIdle(t);
    expect(pageBadgeTexts(t, 1), ['1', '2', '3', '4']);
    await drainDrag(t);
  });

  testWidgets('leaving edit mode under a held drag ends it and numbers stay right', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[4, 2]]));
    final g = await _lift(t, 'L1d1s0', 2.2);
    c.editMode.value = false;
    await t.pump();
    await t.pump();
    await g.up();
    await t.pump(const Duration(milliseconds: 400));
    expect(dayIds(c, 1), ['L1d1s0', 'L1d1s1', 'L1d1s2', 'L1d1s3']);
    _expectIdle(t);
    expect(pageBadgeTexts(t, 1), ['1', '2', '3', '4']);
    c.editMode.value = true;
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    await _dragHandle(t, 'L1d1s0', 1.2);
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s0', 'L1d1s2', 'L1d1s3']);
    await drainDrag(t);
  });

  testWidgets('folding the city while the drop settles keeps the new order and the right numbers', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[4, 2]]));
    final g = await _lift(t, 'L1d1s0', 1.2);
    await g.up();
    await t.pump();
    await t.pump(const Duration(milliseconds: 32));
    t.widget<TripLegHeader>(find.byType(TripLegHeader).first).onToggle!();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s0', 'L1d1s2', 'L1d1s3']);
    expect(_state(t), isNull);
    t.widget<TripLegHeader>(find.byType(TripLegHeader).first).onToggle!();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(pageBadgeTexts(t, 1), ['1', '2', '3', '4']);
    await drainDrag(t);
  });

  testWidgets('a second finger on another row does not cancel the drag or lose the drop', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[4, 2]]));
    final g = await _lift(t, 'L1d1s0', 1.2);
    final g2 = await t.startGesture(t.getCenter(handleOf('L1d1s3')), pointer: 77);
    await t.pump(const Duration(milliseconds: 16));
    expect(proxyRows, findsOneWidget);
    await g2.cancel();
    await t.pump(const Duration(milliseconds: 16));
    expect(proxyRows, findsOneWidget);
    await g.up();
    await settleDrop(t);
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s0', 'L1d1s2', 'L1d1s3']);
    _expectIdle(t);
    await drainDrag(t);
  });

  testWidgets('a touch while the drop settles does not lose the drop', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[4, 2]]));
    final g = await _lift(t, 'L1d1s0', 1.2);
    await g.up();
    await t.pump();
    await t.pump(const Duration(milliseconds: 32));
    final g2 = await t.startGesture(t.getCenter(handleOf('L1d1s3')), pointer: 77);
    await t.pump(const Duration(milliseconds: 16));
    await g2.cancel();
    await t.pump(const Duration(milliseconds: 400));
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s0', 'L1d1s2', 'L1d1s3']);
    _expectIdle(t);
    expect(pageBadgeTexts(t, 1), ['1', '2', '3', '4']);
    await drainDrag(t);
  });

  testWidgets('a second finger on another day cannot hijack the cross-day drop', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[3, 3]]));
    final from = t.getCenter(handleOf('L1d1s0'));
    final target = Offset(t.getCenter(row('L1d1s0')).dx, t.getRect(row('L1d2s0')).bottom);
    final delta = target - t.getCenter(row('L1d1s0'));
    final g = await t.startGesture(from);
    for (var i = 1; i <= 12; i++) {
      await g.moveTo(from + delta * (i / 12));
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(_state(t)?.targetDay, 2);
    final g2 = await t.startGesture(t.getCenter(handleOf('L1d2s2')), pointer: 77);
    await g2.moveBy(const Offset(0, -30));
    await t.pump(const Duration(milliseconds: 16));
    await g2.moveBy(const Offset(0, -30));
    await t.pump(const Duration(milliseconds: 16));
    await g2.up();
    await t.pump(const Duration(milliseconds: 16));
    await g.up();
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s2']);
    expect(dayIds(c, 2), ['L1d2s0', 'L1d1s0', 'L1d2s1', 'L1d2s2']);
    _expectIdle(t);
    await drainDrag(t);
  });

  testWidgets('new road times arriving under a held drag do not end it', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[4, 2]]));
    final g = await _lift(t, 'L1d1s0', 1.2);
    c.result.value = TripPlanResult(
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
          legs: [const TripLeg(fromId: 'L1d1s0', toId: 'L1d1s1', minutes: 17, km: 1, isEstimate: false)],
        ),
      ],
      warnings: const [],
      osrmAvailable: true,
      dayLimitMinutes: 300,
    );
    await t.pump();
    await t.pump();
    expect(proxyRows, findsOneWidget);
    await g.up();
    await settleDrop(t);
    expect(dayIds(c, 1), ['L1d1s1', 'L1d1s0', 'L1d1s2', 'L1d1s3']);
    _expectIdle(t);
    await drainDrag(t);
  });

  testWidgets('moving the only place of a day to the next day can be undone', (t) async {
    final c = await pumpDragPlan(t, enginePlan([[1, 2]]));
    final from = t.getCenter(handleOf('L1d1s0'));
    final delta = Offset(0, t.getRect(row('L1d2s0')).bottom - t.getCenter(row('L1d1s0')).dy);
    final g = await t.startGesture(from);
    for (var i = 1; i <= 12; i++) {
      await g.moveTo(from + delta * (i / 12));
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    expect(dayIds(c, 1), isEmpty);
    expect(dayIds(c, 2), ['L1d2s0', 'L1d1s0', 'L1d2s1']);
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.text(TripStringsV2Plan.undo).last);
    await t.pump();
    expect(dayIds(c, 1), ['L1d1s0']);
    expect(dayIds(c, 2), ['L1d2s0', 'L1d2s1']);
    _expectIdle(t);
    await drainDrag(t);
  });
}
