import 'dart:io';

import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:bakhli/features/trip/models/trip_plan_model.dart';
import 'package:bakhli/features/trip/utils/trip_leg_draft.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../journeys/fake_api.dart';
import 'support/engine_rig.dart';

TripLegDraft draftOf(TripPlanController c, int legIndex) {
  final p = c.plan.value!;
  return TripLegDraft.from(
    p,
    legIndex,
    frozenDays: 0,
    otherLegsDayCount: p.days.length - p.legDayCount(legIndex),
    otherLegsSpotCount: p.spotCount - p.legSpotCount(legIndex),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('apply_gs').path);
    await GetStorage.init();
  });
  tearDown(Get.reset);

  test('apply_touches_only_that_city', () {
    final c = engineRig(enginePlan([[2, 1], [2, 2], [1]]));
    final before = c.plan.value!;
    final d = draftOf(c, 2);
    expect(d.move('L2d2s0', 0, 0), TripDraftBlock.none);
    expect(c.applyLegDraft(2, d), TripLegApplyBlock.none);
    final after = c.plan.value!;
    expect(legSignature(after, 1), legSignature(before, 1));
    expect(legSignature(after, 3), legSignature(before, 3));
    expect(legSignature(after, 2), [':L2d2s0,L2d1s0,L2d1s1', ':L2d2s1']);
    expect(after.legs.map((l) => l.cityKey).toList(), [1, 2, 3]);
    expect(after.days.map((x) => x.day).toList(), [1, 2, 3, 4, 5]);
  });

  test('apply_shifts_later_city_dates_by_the_delta', () {
    final c = engineRig(enginePlan([[2], [2, 1], [1]]));
    final oldStart = c.plan.value!.legStart(3);
    final oldDate = c.dateOf(oldStart)!;
    final d = draftOf(c, 2);
    expect(d.addDay(), TripDraftBlock.none);
    expect(c.applyLegDraft(2, d), TripLegApplyBlock.emptyDay);
    expect(d.move('L2d1s1', 2, 0), TripDraftBlock.none);
    expect(d.firstEmptyDay, isNull);
    expect(c.applyLegDraft(2, d), TripLegApplyBlock.none);
    final p = c.plan.value!;
    expect(p.legDayCount(2), 3);
    expect(p.legStart(3), oldStart + 1);
    expect(c.dateOf(p.legStart(3)), DateTime(oldDate.year, oldDate.month, oldDate.day + 1));
    expect(legSignature(p, 1), [':L1d1s0,L1d1s1']);
    expect(legSignature(p, 3), [':L3d1s0']);
  });

  test('apply_saves_once', () async {
    final api = installFakeApi([
      FakeRoute('PUT', '/trips/{id}', (o) {
        final body = o.data as Map;
        return engineTripJson(TripPlan.fromJson(Map<String, dynamic>.from(body['plan'] as Map)));
      }),
      FakeRoute.value('POST', '/trips/plan', null, code: 503, errorType: 'Down'),
    ]);
    final c = engineRig(enginePlan([[2, 2], [1]]));
    var writes = 0;
    final sub = c.plan.listen((_) => writes++);
    addTearDown(sub.cancel);
    final d = draftOf(c, 1);
    expect(d.move('L1d1s0', 1, 2), TripDraftBlock.none);
    expect(d.move('L1d2s0', 0, 0), TripDraftBlock.none);
    expect(c.applyLegDraft(1, d), TripLegApplyBlock.none);
    expect(writes, 1);
    expect(await c.flushPendingSave(), isTrue);
    expect(api.calls('PUT', '/trips/t1').length, 1);
    expect(await c.flushPendingSave(), isTrue);
    expect(api.calls('PUT', '/trips/t1').length, 1);
    final sent = TripPlan.fromJson(Map<String, dynamic>.from((api.calls('PUT', '/trips/t1').single.data as Map)['plan'] as Map));
    expect(legSignature(sent, 1), [':L1d2s0,L1d1s1', ':L1d2s1,L1d1s0']);
  });

  test('apply_refused_when_locked', () {
    final c = engineRig(enginePlan([[2, 2]]), lock: lockedByRequest);
    final before = c.plan.value;
    final d = draftOf(c, 1);
    expect(d.move('L1d1s0', 1, 0), TripDraftBlock.none);
    expect(c.applyLegDraft(1, d), TripLegApplyBlock.locked);
    expect(identical(c.plan.value, before), isTrue);
  });

  test('apply_refused_when_stale', () {
    final c = engineRig(enginePlan([[2, 2], [2]]));
    final d = draftOf(c, 1);
    expect(d.move('L1d1s0', 1, 0), TripDraftBlock.none);
    c.reorder(2, 0, 2);
    final changed = c.plan.value;
    expect(c.applyLegDraft(1, d), TripLegApplyBlock.stale);
    expect(identical(c.plan.value, changed), isTrue);

    final other = engineRig(enginePlan([[2, 2], [2]]));
    final d2 = draftOf(other, 1);
    expect(d2.move('L1d1s0', 1, 0), TripDraftBlock.none);
    other.reorder(3, 0, 2);
    expect(other.applyLegDraft(1, d2), TripLegApplyBlock.none);
  });

  test('apply_refused_with_an_empty_day_but_allows_a_rest_day', () {
    final c = engineRig(enginePlan([[2, 2]]));
    final d = draftOf(c, 1);
    expect(d.addDay(), TripDraftBlock.none);
    expect(c.applyLegDraft(1, d), TripLegApplyBlock.emptyDay);
    expect(c.plan.value!.days.length, 2);

    final rest = engineRig(enginePlan([[2, 0, 2]], restDays: {2}));
    final r = draftOf(rest, 1);
    expect(r.firstEmptyDay, isNull);
    expect(r.move('L1d1s0', 2, 0), TripDraftBlock.none);
    expect(rest.applyLegDraft(1, r), TripLegApplyBlock.none);
    final p = rest.plan.value!;
    expect(p.days.length, 3);
    expect(p.days[1].restDay, isTrue);
    expect(p.days[1].spots, isEmpty);
    expect(legSignature(p, 1), [':L1d1s1', 'R:', ':L1d1s0,L1d3s0,L1d3s1']);
  });

  test('apply refuses a draft that edits a past day of a running city', () {
    final c = engineRig(enginePlan([[2, 2, 2]], start: daysFromToday(-1)));
    final d = draftOf(c, 1);
    expect(d.move('L1d1s0', 2, 0), TripDraftBlock.none);
    final before = c.plan.value;
    expect(c.applyLegDraft(1, d), TripLegApplyBlock.readOnly);
    expect(identical(c.plan.value, before), isTrue);
  });

  test('apply says running when a draft shrinks a running city below its minimum', () {
    final c = engineRig(enginePlan([[1, 0]], start: daysFromToday(-1)));
    expect(c.minDaysForLeg(1), 2);
    final d = draftOf(c, 1);
    expect(d.deleteDay(1), TripDraftBlock.none);
    final before = c.plan.value;
    expect(c.applyLegDraft(1, d), TripLegApplyBlock.running);
    expect(identical(c.plan.value, before), isTrue);
  });

  test('apply refuses a city whose days are all past', () {
    final c = engineRig(enginePlan([[1], [1, 1]], start: daysFromToday(-2)));
    expect(c.applyLegDraft(1, draftOf(c, 1)), TripLegApplyBlock.readOnly);
  });
}
