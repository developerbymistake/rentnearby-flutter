import 'dart:math';

import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/trip_constants.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/engine_rig.dart';

List<String> _sig(TripPlan p) => [for (final d in p.days) '${d.day}|${d.leg}|${d.restDay ? 'R' : ''}|${d.spots.map((s) => s.id).join(',')}'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  test('random reorders, cross-day moves and undos keep every plan invariant', () {
    final r = Random(20261123);
    for (var round = 0; round < 60; round++) {
      final shape = [
        for (var k = 0; k < 1 + r.nextInt(3); k++) [for (var d = 0; d < 1 + r.nextInt(4); d++) r.nextInt(TripConstants.maxSpotsPerDay + 1)],
      ];
      final rest = <int>{};
      var n = 0;
      for (final leg in shape) {
        for (final count in leg) {
          n++;
          if (count == 0 && r.nextBool()) rest.add(n);
        }
      }
      final c = engineRig(enginePlan(shape, restDays: rest));
      final legOf = {for (final d in c.plan.value!.days) for (final s in d.spots) s.id: d.leg};
      final dayLegs = [for (final d in c.plan.value!.days) d.leg];
      for (var step = 0; step < 40; step++) {
        final p = c.plan.value!;
        final before = _sig(p);
        final from = p.days[r.nextInt(p.days.length)];
        final to = p.days[r.nextInt(p.days.length)];
        final index = r.nextInt(8) - 1;
        final snap = c.snapshotDays([from.day, to.day]);
        bool moved;
        if (from.spots.isEmpty) {
          moved = c.reorderTo(from.day, 0, 1);
          expect(moved, isFalse);
        } else if (from.day == to.day) {
          final a = r.nextInt(from.spots.length);
          moved = c.reorderTo(from.day, a, index);
          final ok = index >= 0 && index < from.spots.length && index != a;
          expect(moved, ok, reason: 'round $round step $step');
          if (moved) expect(c.plan.value!.dayAt(from.day)!.spots[index].id, from.spots[a].id);
        } else {
          final id = from.spots[r.nextInt(from.spots.length)].id;
          final can = c.canDropOn(id, to.day);
          moved = c.moveSpot(id, to.day, index: index);
          expect(moved, can, reason: 'round $round step $step');
          expect(can, from.leg == to.leg && to.spots.length < TripConstants.maxSpotsPerDay, reason: 'round $round step $step');
          if (moved) {
            final at = index.clamp(0, to.spots.length);
            expect(c.plan.value!.dayAt(to.day)!.spots[at].id, id);
            expect(c.plan.value!.dayAt(to.day)!.restDay, isFalse);
          }
        }
        final now = c.plan.value!;
        if (!moved) expect(_sig(now), before, reason: 'round $round step $step');
        expect([for (final d in now.days) d.leg], dayLegs);
        expect([for (final d in now.days) d.day], [for (var i = 1; i <= dayLegs.length; i++) i]);
        final seen = <String>{};
        for (final d in now.days) {
          expect(d.spots.length, lessThanOrEqualTo(TripConstants.maxSpotsPerDay));
          expect(d.restDay && d.spots.isNotEmpty, isFalse);
          for (final s in d.spots) {
            expect(seen.add(s.id), isTrue);
            expect(legOf[s.id], d.leg);
          }
        }
        expect(seen.length, legOf.length);
        if (moved && r.nextBool()) {
          expect(c.restoreDays(snap), isTrue, reason: 'round $round step $step');
          expect(_sig(c.plan.value!), before, reason: 'round $round step $step');
        }
      }
    }
  });
}
