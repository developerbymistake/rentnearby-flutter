import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_enquiry_model.dart';
import 'package:bakhli/features/trip/models/trip_model.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/models/trip_spot_model.dart';
import 'package:bakhli/features/trip/trip_constants.dart';
import 'package:bakhli/features/trip/utils/trip_leg_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'support/engine_rig.dart';

const _spotModel = TripSpotModel(
  id: 'new1',
  source: 'atlas',
  name: 'New place',
  latitude: 29.4,
  longitude: 79.4,
  category: 'attraction',
  visitMinutes: 60,
);

TripEnquiryModel _stayAsk(DateTime night) => TripEnquiryModel(
      id: 'e1',
      tripId: 't1',
      listingId: 's1',
      listingName: 'Deodar',
      status: TripEnquiryStatuses.asked,
      displayStatusWire: 'asked',
      checkIn: night,
      checkOut: DateTime(night.year, night.month, night.day + 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(Get.reset);

  test('past_day_edits_are_refused_by_the_engine', () {
    final c = engineRig(enginePlan([[2, 2, 2]], start: daysFromToday(-1)));
    final before = c.plan.value;
    expect(c.isReadOnly, isFalse);
    expect(c.structureBlockForTest(day: 1), TripStructureBlock.pastDay);
    expect(c.moveSpot('L1d1s0', 3), isFalse);
    expect(c.moveSpot('L1d3s0', 1), isFalse);
    c.reorder(1, 0, 2);
    c.removeSpot('L1d1s0');
    c.insertSpotAt(engineSpot('x'), 1, 0);
    c.setRestDay(1, true);
    expect(c.removeDay(1), TripDayRemoveBlock.readOnly);
    expect(c.addSpots([_spotModel], day: 1), isFalse);
    expect(identical(c.plan.value, before), isTrue);

    expect(c.moveSpot('L1d2s0', 3), isTrue);
    expect(c.plan.value!.dayAt(1)!.spots.map((s) => s.id).toList(), ['L1d1s0', 'L1d1s1']);
  });

  test('add places never land on a past day', () {
    final c = engineRig(enginePlan([[1, 6, 6]], start: daysFromToday(-1)));
    expect(c.addSpots([_spotModel], legIndex: 1), isFalse);
    expect(c.plan.value!.dayAt(1)!.spots.length, 1);
  });

  test('remove_day_spreads_earliest_first', () {
    List<List<String>> run() {
      final c = engineRig(enginePlan([[3, 1, 3, 2]]));
      expect(c.removeDay(4), TripDayRemoveBlock.none);
      return [for (final d in c.plan.value!.days) [for (final s in d.spots) s.id]];
    }

    final first = run();
    expect(first, [
      ['L1d1s0', 'L1d1s1', 'L1d1s2', 'L1d4s0', 'L1d4s1'],
      ['L1d2s0'],
      ['L1d3s0', 'L1d3s1', 'L1d3s2'],
    ]);
    expect(run(), first);

    final full = engineRig(enginePlan([[6, 5, 1, 2]]));
    expect(full.removeDay(4), TripDayRemoveBlock.none);
    expect([for (final d in full.plan.value!.days) d.spots.length], [6, 6, 2]);
  });

  test('remove day respects bookings, running cities and the lock', () {
    final start = DateTime(2030, 11, 1);
    final booked = engineRig(enginePlan([[2, 2], [1]], start: start), rows: [_stayAsk(DateTime(2030, 11, 2))]);
    expect(booked.removeDayReason(2), TripLegApplyBlock.bookings);
    expect(booked.removeDay(2), TripDayRemoveBlock.readOnly);
    expect(booked.plan.value!.days.length, 3);

    final running = engineRig(enginePlan([[1, 1]], start: daysFromToday(-1)));
    expect(running.removeDayReason(2), TripLegApplyBlock.running);
    expect(running.removeDay(2), TripDayRemoveBlock.readOnly);

    final locked = engineRig(enginePlan([[1, 1]]), lock: lockedByRequest);
    expect(locked.removeDayReason(2), TripLegApplyBlock.locked);
    expect(locked.removeDay(2), TripDayRemoveBlock.readOnly);
    expect(engineRig(enginePlan([[1, 1]])).removeDayReason(2), TripLegApplyBlock.none);
    expect(locked.plan.value!.days.length, 2);
  });

  test('offline_shrink_never_exceeds_six', () async {
    final c = engineRig(enginePlan([[4, 4, 4]]));
    c.offline.value = true;
    expect(c.canSetLegDays(1, 2), TripLegEditBlock.none);
    expect(await c.setLegDays(1, 2), isTrue);
    expect([for (final d in c.plan.value!.days) d.spots.length], [6, 6]);

    final running = engineRig(enginePlan([[1, 6, 5]], start: daysFromToday(-1)));
    final before = running.plan.value;
    expect(running.canSetLegDays(1, 2), TripLegEditBlock.none);
    expect(await running.setLegDays(1, 2), isFalse);
    expect(identical(running.plan.value, before), isTrue);
    expect(running.sizeLegForTest(1, 2), isFalse);
    for (final d in running.plan.value!.days) {
      expect(d.spots.length, lessThanOrEqualTo(TripConstants.maxSpotsPerDay));
    }
  });

  test('a draft with seven places on a day is refused by the engine', () {
    final c = engineRig(enginePlan([[6, 1]]));
    final p = c.plan.value!;
    final d = TripLegDraft.from(p, 1, frozenDays: 0, otherLegsDayCount: 0, otherLegsSpotCount: 0);
    expect(d.move('L1d2s0', 0, 0), TripDraftBlock.dayFull);
    expect(c.moveSpot('L1d2s0', 1), isFalse);
    expect(c.plan.value!.dayAt(1)!.spots.length, 6);
  });

  test('add_day_respects_booking_and_running_leg_blocks', () {
    final start = DateTime(2030, 11, 1);
    final booked = engineRig(enginePlan([[1, 1], [1]], start: start), rows: [_stayAsk(DateTime(2030, 11, 3))]);
    expect(booked.growthBlockedByBookings(1), isTrue);
    expect(booked.addDay(afterDay: 2), TripDayAddBlock.bookings);
    expect(booked.plan.value!.days.length, 3);
    expect(booked.addDay(afterDay: 3), TripDayAddBlock.none);
    expect(booked.plan.value!.days.length, 4);

    final running = engineRig(enginePlan([[1, 1, 1]], start: daysFromToday(-1)));
    expect(running.addDay(afterDay: 1), TripDayAddBlock.running);
    expect(running.plan.value!.days.length, 3);
    expect(running.addDay(afterDay: 2), TripDayAddBlock.none);
    expect(running.plan.value!.days.length, 4);
    expect(running.plan.value!.dayAt(3)!.spots, isEmpty);

    final locked = engineRig(enginePlan([[1]]), lock: lockedByRequest);
    expect(locked.canAddDay, isFalse);
    expect(locked.addDay(), TripDayAddBlock.locked);

    final done = engineRig(enginePlan([[1]]), status: TripStatuses.completed);
    expect(done.addDay(), TripDayAddBlock.readOnly);

    final full = engineRig(enginePlan([List.filled(TripConstants.maxDaysCap, 1)]));
    expect(full.addDayBlock(), TripDayAddBlock.maxDays);
  });
}
