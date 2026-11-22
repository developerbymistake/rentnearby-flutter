import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/owner_core/plan/plan_bindings.dart';
import 'package:bakhli/features/owner_core/plan/plan_card_state.dart';
import 'package:bakhli/features/owner_core/session/owner_plan_sync.dart';
import 'package:bakhli/repositories/plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../support/owner_fakes.dart';

// JT-A-LC-2: the admin grants Plus while payment is OFF, then revokes it, while the app is open.
// Each real change of /plans/me reloads the owner screens once; the card state follows D-09 (FX-03, FX-13).
Map<String, dynamic> _free() => {
      'paymentEnabled': false,
      'featureKey': 'Stay',
      'isPaid': false,
      'limits': {'photos': 8, 'roomTypes': 6},
    };

Map<String, dynamic> _granted() => {
      ..._free(),
      'isPaid': true,
      'source': 'AdminGrant',
      'endsAt': '2027-01-31T18:30:00Z',
      'plan': {'id': 'plus', 'name': 'Plus', 'isDefault': false},
    };

Map<String, dynamic> _revokedPaymentOn() => {
      'paymentEnabled': true,
      'featureKey': 'Stay',
      'isPaid': false,
      'limits': {'photos': 2, 'roomTypes': 2},
      'hidden': {'photos': 3, 'roomTypes': 1},
      'play': {'state': 'SUBSCRIPTION_STATE_EXPIRED', 'expiryAt': DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String(), 'productId': 'p'},
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

  test('grant while OFF -> AdminGrant (not "Paid plans are coming"); revoke -> Ended with Choose; one reload each', () async {
    var homeReloads = 0;
    OwnerPlanSync.register('stay-home', () => homeReloads++);
    PlanBindings.ensure();
    await flush();
    final plans = Get.find<PlanController>();
    expect(PlanCardStates.ofPlan(plans.myPlan.value), PlanCardState.paymentOff);

    repo.bodies
      ..clear()
      ..add(_granted());
    plans.invalidate();
    plans.invalidate();
    await flush();
    expect(homeReloads, 1, reason: 'one plan-changed signal for the grant');
    expect(PlanCardStates.ofPlan(plans.myPlan.value), PlanCardState.adminGrant);

    plans.invalidate();
    await flush();
    expect(homeReloads, 1, reason: 'the same answer again changes nothing');

    repo.bodies
      ..clear()
      ..add(_revokedPaymentOn());
    plans.invalidate();
    await flush();
    expect(homeReloads, 2, reason: 'one signal for the revoke');
    final me = plans.myPlan.value;
    expect(PlanCardStates.ofPlan(me), PlanCardState.ended);
    final copy = _StayCopy();
    expect(copy.canChoose(me), isTrue, reason: 'hidden photos and rooms open Choose what stays');
  });
}

class _StayCopy extends PlanRoleCopy {
  @override
  String get featureKey => 'Stay';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
