import 'package:bakhli/config/notification_types.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/owner_core/plan/plan_bindings.dart';
import 'package:bakhli/features/owner_core/session/owner_plan_sync.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/repositories/plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';

Map<String, dynamic> _free({String? endsAt}) => {
      'paymentEnabled': true,
      'isPaid': false,
      'endsAt': ?endsAt,
      'limits': {'photos': 2, 'routes': 1},
    };

void main() {
  late FakePlanRepository repo;

  setUp(() {
    Get.reset();
    OwnerPlanSync.reset();
    repo = FakePlanRepository([_free()]);
    Get.put<PlanRepository>(repo, permanent: true);
  });

  tearDown(() {
    PlanBindings.dispose();
    Get.reset();
  });

  Future<void> flush() => Future<void>.delayed(const Duration(milliseconds: 400));

  test('the same answer twice calls no handler', () async {
    {
      var calls = 0;
      OwnerPlanSync.register('stay', () => calls++);
      PlanBindings.ensure();
      await flush();
      Get.find<PlanController>().invalidate();
      await flush();
      expect(repo.meCalls, 2);
      expect(calls, 0);
    }
  });

  test('a changed endsAt calls every handler once, debounced', () async {
    {
      var stay = 0;
      var taxi = 0;
      OwnerPlanSync.register('stay', () => stay++);
      OwnerPlanSync.register('taxi', () => taxi++);
      PlanBindings.ensure();
      await flush();
      repo.push({..._free(endsAt: '2026-12-01T00:00:00Z'), 'isPaid': true});
      final c = Get.find<PlanController>();
      c.invalidate();
      c.invalidate();
      await pumpEventQueue();
      expect(stay, 0, reason: 'debounced');
      await flush();
      expect(stay, 1);
      expect(taxi, 1);
      expect(c.planVersion.value, 1);
    }
  });

  test('a burst of invalidations while one is in flight costs at most two fetches', () async {
    {
      PlanBindings.ensure();
      await flush();
      final before = repo.meCalls;
      final c = Get.find<PlanController>();
      for (var i = 0; i < 5; i++) {
        c.invalidate();
      }
      await flush();
      expect(repo.meCalls - before, lessThanOrEqualTo(2));
    }
  });

  test('after reset no handler is called', () async {
    {
      var calls = 0;
      OwnerPlanSync.register('stay', () => calls++);
      PlanBindings.ensure();
      await flush();
      OwnerPlanSync.reset();
      repo.push(_free(endsAt: '2027-01-01T00:00:00Z'));
      Get.find<PlanController>().invalidate();
      await flush();
      expect(calls, 0);
      expect(OwnerPlanSync.names, isEmpty);
    }
  });

  test('fingerprint changes with hidden rows and the auto-renew switch only when they change', () {
    final base = MyPlanModel.fromJson(_free());
    final same = MyPlanModel.fromJson(_free());
    final hidden = MyPlanModel.fromJson({..._free(), 'hidden': {'routes': 2}});
    expect(PlanController.fingerprintOf(base), PlanController.fingerprintOf(same));
    expect(PlanController.fingerprintOf(base), isNot(PlanController.fingerprintOf(hidden)));
  });

  test('a hub PlanActivated event (PascalCase) triggers one /plans/me', () async {
    PlanBindings.ensure();
    await flush();
    final before = repo.meCalls;
    Get.find<PlanController>().onPushNotification('PlanActivated');
    Get.find<PlanController>().onPushNotification('plan_activated');
    await flush();
    expect(repo.meCalls - before, lessThanOrEqualTo(2));
    expect(repo.meCalls - before, greaterThanOrEqualTo(1));
  });

  test('hub types are mapped to the wire form the owner seams use', () {
    expect(NotificationTypeKeys.toWire('StayEditApproved'), 'stay_edit_approved');
    expect(NotificationTypeKeys.toWire('taxi_selected'), 'taxi_selected');
    expect(NotificationTypeKeys.isOwnerWork(NotificationTypeKeys.toWire('PlanLimitsChanged')), isTrue);
    expect(NotificationTypeKeys.toWire(null), isNull);
  });
}
