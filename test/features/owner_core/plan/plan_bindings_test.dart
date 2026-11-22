import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/owner_core/plan/plan_bindings.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/repositories/plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';

void main() {
  late FakePlanRepository repo;

  setUp(() {
    Get.reset();
    PlanGate.debugPlan = null;
    repo = FakePlanRepository([
      {'paymentEnabled': true, 'limits': {'routes': 1}},
    ]);
    Get.put<PlanRepository>(repo, permanent: true);
  });

  tearDown(() {
    PlanBindings.dispose();
    Get.reset();
  });

  test('ensure twice registers one controller and loads once', () async {
    PlanBindings.ensure();
    final first = Get.find<PlanController>();
    PlanBindings.ensure();
    expect(identical(first, Get.find<PlanController>()), isTrue);
    await pumpEventQueue();
    expect(repo.meCalls, 1);
  });

  test('loaded is false before the first answer and true after', () async {
    PlanBindings.ensure();
    expect(PlanGate.loaded, isFalse);
    await pumpEventQueue();
    expect(PlanGate.loaded, isTrue);
    expect(PlanGate.paymentOn, isTrue);
  });

  test('a failed first answer keeps loaded false', () async {
    repo.failWith = Exception('offline');
    PlanBindings.ensure();
    await pumpEventQueue();
    expect(PlanGate.loaded, isFalse);
    expect(Get.find<PlanController>().planLoadFailed.value, isTrue);
  });

  test('the controller survives a route change (permanent) and dispose removes it', () async {
    PlanBindings.ensure();
    await pumpEventQueue();
    Get.deleteAll();
    expect(Get.isRegistered<PlanController>(), isTrue);
    PlanBindings.dispose();
    expect(Get.isRegistered<PlanController>(), isFalse);
    expect(Get.isRegistered<PlanRepository>(), isFalse);
  });

  test('after logout a new ensure gives a fresh controller', () async {
    PlanBindings.ensure();
    await pumpEventQueue();
    final old = Get.find<PlanController>();
    PlanBindings.dispose();
    Get.put<PlanRepository>(repo, permanent: true);
    PlanBindings.ensure();
    expect(identical(old, Get.find<PlanController>()), isFalse);
    expect(PlanGate.loaded, isFalse);
  });

  test('fresh ensure after a role pick clears the old plan and reloads', () async {
    PlanBindings.ensure();
    await pumpEventQueue();
    repo.push({'paymentEnabled': false, 'limits': {'routes': 5}});
    PlanBindings.ensure(fresh: true);
    expect(PlanGate.loaded, isFalse);
    await pumpEventQueue();
    expect(PlanGate.loaded, isTrue);
  });
}
