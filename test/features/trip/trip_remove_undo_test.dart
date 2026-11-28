import 'dart:io';

import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/trip/controllers/trip_plan_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'support/engine_rig.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

List<int> _dayNumbers(TripPlanController c) => [for (final d in c.plan.value!.days) d.day];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.createTempSync('remove_undo_gs').path);
    await GetStorage.init();
  });
  tearDown(Get.reset);

  test('a_remove_then_undo_restores_the_exact_days', () {
    final c = engineRig(enginePlan([[2, 2]]));
    final before = legSignature(c.plan.value!, 1);
    final r = c.removeSpotForUndo('L1d1s0');
    expect(r, isNotNull);
    expect(r!.spotId, 'L1d1s0');
    expect(r.tripId, 't1');
    expect(legSignature(c.plan.value!, 1), [':L1d1s1', ':L1d2s0,L1d2s1']);
    expect(c.undoRemove(r), isTrue);
    expect(legSignature(c.plan.value!, 1), before);
    expect(_dayNumbers(c), [1, 2]);
    expect(c.undoRemove(r), isFalse);
    expect(legSignature(c.plan.value!, 1), before);
  });

  test('b_undo_refused_after_days_are_renumbered', () {
    final c = engineRig(enginePlan([[2, 2]]));
    final r = c.removeSpotForUndo('L1d2s0')!;
    expect(c.addDay(afterDay: 1), TripDayAddBlock.none);
    final changed = legSignature(c.plan.value!, 1);
    expect(changed, [':L1d1s0,L1d1s1', ':', ':L1d2s1']);
    expect(c.undoRemove(r), isFalse);
    expect(legSignature(c.plan.value!, 1), changed);
    expect(_dayNumbers(c), [1, 2, 3]);

    final m = engineRig(enginePlan([[1, 1, 1]]));
    final r2 = m.removeSpotForUndo('L1d3s0')!;
    expect(m.removeDay(1), TripDayRemoveBlock.none);
    final after = legSignature(m.plan.value!, 1);
    expect(m.undoRemove(r2), isFalse);
    expect(legSignature(m.plan.value!, 1), after);
  });

  test('c_last_place_of_a_day_goes_back_to_that_day', () {
    final c = engineRig(enginePlan([[1, 2]]));
    final r = c.removeSpotForUndo('L1d1s0')!;
    final p = c.plan.value!;
    expect(p.days.length, 2);
    expect(p.dayAt(1)!.spots, isEmpty);
    expect(c.undoRemove(r), isTrue);
    final back = c.plan.value!;
    expect(back.dayOfSpot('L1d1s0'), 1);
    expect(back.dayAt(1)!.spots.indexWhere((s) => s.id == 'L1d1s0'), 0);
    expect(legSignature(back, 1), [':L1d1s0', ':L1d2s0,L1d2s1']);
  });

  test('d_locked_plan_removes_nothing', () {
    final c = engineRig(enginePlan([[2, 2]]), lock: lockedByRequest);
    final before = c.plan.value;
    expect(c.removeSpotForUndo('L1d1s0'), isNull);
    expect(identical(c.plan.value, before), isTrue);
    expect(c.removeSpotForUndo('nope'), isNull);
  });

  test('e_closed_controller_refuses_undo', () {
    Get.put<TabConfigController>(_Tabs());
    final plan = enginePlan([[2, 2]]);
    final c = TripPlanController();
    c.plan.value = plan;
    c.trip.value = engineTrip(plan);
    Get.put<TripPlanController>(c);
    final r = c.removeSpotForUndo('L1d1s0')!;
    final after = c.plan.value;
    Get.delete<TripPlanController>(force: true);
    expect(c.isClosed, isTrue);
    expect(c.undoRemove(r), isFalse);
    expect(identical(c.plan.value, after), isTrue);
  });

  test('undo_refused_for_another_trip', () {
    final c = engineRig(enginePlan([[2, 2]]));
    final r = c.removeSpotForUndo('L1d1s0')!;
    final other = TripSpotRemoval(tripId: 'other', spotId: r.spotId, before: r.before, afterKey: r.afterKey);
    expect(c.undoRemove(other), isFalse);
    expect(c.plan.value!.spotById('L1d1s0'), isNull);
    expect(c.undoRemove(r), isTrue);
  });
}
