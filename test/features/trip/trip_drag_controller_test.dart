import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_result_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/engine_rig.dart';

List<String> ids(TripPlan p, int day) => [for (final s in p.dayAt(day)!.spots) s.id];

TripPlanResult resultFor(int day, List<(String, String, int)> legs) => TripPlanResult(
      days: [
        TripPlanDay(
          day: day,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  group('reorder', () {
    test('reorderTo and the old reorder give the same order', () {
      final a = engineRig(enginePlan([[3, 2]]));
      expect(a.reorderTo(1, 0, 2), isTrue);
      expect(ids(a.plan.value!, 1), ['L1d1s1', 'L1d1s2', 'L1d1s0']);
      final b = engineRig(enginePlan([[3, 2]]));
      b.reorder(1, 0, 3);
      expect(ids(b.plan.value!, 1), ids(a.plan.value!, 1));
    });

    test('same index, out of range and missing day change nothing', () {
      final c = engineRig(enginePlan([[3, 2]]));
      final before = c.plan.value;
      expect(c.reorderTo(1, 1, 1), isFalse);
      expect(c.reorderTo(1, 0, 3), isFalse);
      expect(c.reorderTo(1, -1, 0), isFalse);
      expect(c.reorderTo(1, 3, 0), isFalse);
      expect(c.reorderTo(9, 0, 1), isFalse);
      expect(identical(c.plan.value, before), isTrue);
    });

    test('other days keep the same spots list and other legs keep empty days', () {
      final c = engineRig(enginePlan([[3, 2], [1, 0, 0]]));
      final before = c.plan.value!;
      expect(c.reorderTo(1, 2, 0), isTrue);
      final p = c.plan.value!;
      for (final d in [2, 3, 4, 5]) {
        expect(identical(p.dayAt(d)!.spots, before.dayAt(d)!.spots), isTrue, reason: 'day $d');
      }
      expect(p.days.length, before.days.length);
      expect(p.legDayCount(2), 3);
    });

    test('refused when locked, completed, past day or needs update', () {
      final locked = engineRig(enginePlan([[3]]), lock: lockedByRequest);
      expect(locked.reorderTo(1, 0, 2), isFalse);
      final done = engineRig(enginePlan([[3]]), status: TripStatuses.completed);
      expect(done.reorderTo(1, 0, 2), isFalse);
      final past = engineRig(enginePlan([[3, 3]], start: daysFromToday(-2)));
      expect(past.reorderTo(1, 0, 2), isFalse);
      final stale = engineRig(enginePlan([[3]]));
      stale.needsUpdate.value = true;
      expect(stale.reorderTo(1, 0, 2), isFalse);
      for (final c in [locked, done, past, stale]) {
        expect(ids(c.plan.value!, 1).first, 'L1d1s0');
      }
    });
  });

  group('undo', () {
    test('snapshot, reorder, restore gives the exact old order', () {
      final c = engineRig(enginePlan([[4, 2]]));
      final snap = c.snapshotDays([1]);
      c.reorderTo(1, 0, 3);
      c.reorderTo(1, 1, 0);
      expect(c.restoreDays(snap), isTrue);
      expect(ids(c.plan.value!, 1), ['L1d1s0', 'L1d1s1', 'L1d1s2', 'L1d1s3']);
    });

    test('restore refuses after the place set changed', () {
      final c = engineRig(enginePlan([[3, 2]]));
      final snap = c.snapshotDays([1]);
      c.reorderTo(1, 0, 2);
      c.removeSpot('L1d1s1', keepEmptyDays: true);
      final before = c.plan.value;
      expect(c.restoreDays(snap), isFalse);
      expect(identical(c.plan.value, before), isTrue);

      final d = engineRig(enginePlan([[2, 2]]));
      final snap2 = d.snapshotDays([1]);
      d.reorderTo(1, 0, 1);
      d.insertSpotAt(engineSpot('x'), 1, 0);
      expect(d.restoreDays(snap2), isFalse);
    });

    test('restore refuses on a locked plan and a past day', () {
      final c = engineRig(enginePlan([[3]]));
      final snap = c.snapshotDays([1]);
      c.reorderTo(1, 0, 2);
      c.trip.value = engineTrip(c.plan.value!, lock: lockedByRequest);
      expect(c.restoreDays(snap), isFalse);

      final past = engineRig(enginePlan([[3, 3]], start: daysFromToday(-2)));
      final d1 = past.plan.value!.dayAt(1)!;
      expect(past.restoreDays([d1.copyWith(spots: d1.spots.reversed.toList())]), isFalse);
      expect(ids(past.plan.value!, 1).first, 'L1d1s0');
    });

    test('each edit is one plan change, applied at once, last order wins', () {
      final c = engineRig(enginePlan([[3]]));
      var changes = 0;
      final w = ever(c.plan, (_) => changes++);
      addTearDown(w.dispose);
      c.reorderTo(1, 0, 2);
      expect(changes, 1);
      expect(ids(c.plan.value!, 1), ['L1d1s1', 'L1d1s2', 'L1d1s0']);
      c.reorderTo(1, 2, 0);
      expect(changes, 2);
      expect(ids(c.plan.value!, 1), ['L1d1s0', 'L1d1s1', 'L1d1s2']);
      expect(c.restoreDays(c.snapshotDays([1])), isFalse);
      expect(changes, 2);
    });
  });

  test('road minutes: server pair, estimate for a new pair, never the old fromId leg', () {
    final c = engineRig(enginePlan([[3]]));
    c.result.value = resultFor(1, [('L1d1s0', 'L1d1s1', 17), ('L1d1s1', 'L1d1s2', 23)]);
    final p = c.plan.value!.dayAt(1)!.spots;
    expect(c.roadMinutesBetween(1, p[0], p[1]), 17);
    expect(c.roadKnown(1, p[0], p[1]), isTrue);
    expect(c.roadKnown(1, p[1], p[0]), isFalse);
    c.reorderTo(1, 0, 1);
    final q = c.plan.value!.dayAt(1)!.spots;
    expect(ids(c.plan.value!, 1), ['L1d1s1', 'L1d1s0', 'L1d1s2']);
    expect(c.roadKnown(1, q[0], q[1]), isFalse);
    expect(c.roadMinutesBetween(1, q[0], q[1]), isNot(23));
    expect(c.roadKnown(1, q[1], q[2]), isFalse);
  });
}
