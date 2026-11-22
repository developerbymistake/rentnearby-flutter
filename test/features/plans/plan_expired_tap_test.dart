import 'package:bakhli/config/app_routes.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/owner_core/plan/plan_card_state.dart';
import 'package:bakhli/features/owner_core/plan/plan_expired_tap.dart';
import 'package:bakhli/features/stay_owner/plan/stay_plan_copy.dart';
import 'package:bakhli/features/taxi_driver/plan/taxi_plan_copy.dart';
import 'package:bakhli/repositories/plan_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/owner_fakes.dart';

final _opened = <String>[];

// No billing gateway in tests: the plan comes straight from the fake repository.
class _Plans extends PlanController {
  @override
  Future<void> refreshPlan({bool force = false}) async {
    myPlan.value = await Get.find<PlanRepository>().getMe(forceRefresh: force);
  }
}

GetPage _stub(String name) => GetPage(
      name: name,
      page: () {
        _opened.add(name);
        return Scaffold(body: Text(name));
      },
    );

Future<FakePlanRepository> _boot(WidgetTester t, Map<String, dynamic> me) async {
  final repo = FakePlanRepository([me]);
  Get.put<PlanRepository>(repo);
  Get.put<PlanController>(_Plans());
  PlanCopies.stay = const StayPlanCopy();
  PlanCopies.taxi = const TaxiPlanCopy();
  await t.pumpWidget(GetMaterialApp(
    getPages: [for (final r in [AppRoutes.plansBilling, AppRoutes.stayPlanVisible, AppRoutes.taxiPlanVisible, AppRoutes.staySpecialPrices]) _stub(r)],
    home: const Scaffold(body: SizedBox()),
  ));
  return repo;
}

void main() {
  setUp(() {
    _opened.clear();
    Get.testMode = true;
  });
  tearDown(() {
    PlanCopies.reset();
    Get.reset();
  });

  test('handles the FCM wire and the hub type only', () {
    expect(PlanExpiredTap.handles('plan_expired'), isTrue);
    expect(PlanExpiredTap.handles('PlanExpired'), isTrue);
    expect(PlanExpiredTap.handles('plan_renewed'), isFalse);
    expect(PlanExpiredTap.handles(null), isFalse);
  });

  testWidgets('stay with hidden photos: fresh /plans/me, then Choose what stays', (t) async {
    final repo = await _boot(t, {'featureKey': 'Stay', 'paymentEnabled': true, 'hidden': {'photos': 3}});
    await t.pump();
    final before = repo.meCalls;
    await PlanExpiredTap.open();
    await t.pumpAndSettle();
    expect(repo.meCalls, greaterThan(before));
    expect(_opened, [AppRoutes.stayPlanVisible]);
  });

  testWidgets('taxi with hidden routes: Choose your route', (t) async {
    await _boot(t, {'featureKey': 'Taxi', 'paymentEnabled': true, 'hidden': {'routes': 2}});
    await PlanExpiredTap.open();
    await t.pumpAndSettle();
    expect(_opened, [AppRoutes.taxiPlanVisible]);
  });

  testWidgets('nothing hidden: Plans & Billing (both roles)', (t) async {
    await _boot(t, {'featureKey': 'Taxi', 'paymentEnabled': true});
    await PlanExpiredTap.open();
    await t.pumpAndSettle();
    expect(_opened, [AppRoutes.plansBilling]);
  });

  testWidgets('stay with only paused special prices: the Special prices list (D-27)', (t) async {
    await _boot(t, {'featureKey': 'Stay', 'paymentEnabled': true, 'hidden': {'specialPrices': 2}});
    await PlanExpiredTap.open();
    await t.pumpAndSettle();
    expect(_opened, [AppRoutes.staySpecialPrices]);
  });
}
