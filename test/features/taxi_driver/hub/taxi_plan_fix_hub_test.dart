import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/owner_core/plan/plan_card_state.dart';
import 'package:bakhli/features/taxi/setup/taxi_routes_screen.dart';
import 'package:bakhli/features/taxi/setup/taxi_setup_controller.dart';
import 'package:bakhli/features/taxi_driver/hub/taxi_hub_controller.dart';
import 'package:bakhli/features/taxi_driver/plan/taxi_plan_copy.dart';
import 'package:bakhli/features/taxi_driver/plan/taxi_plan_strings.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/real_phone.dart';
import '../../plans/plans_harness.dart';
import '../core/taxi_fixtures.dart';

class _CountPlan extends PlanController {
  _CountPlan(this.plan);
  final MyPlanModel plan;
  int invalidates = 0;

  @override
  // ignore: must_call_super
  void onInit() {
    myPlan.value = plan;
  }

  @override
  Future<void> invalidate() async {
    invalidates++;
  }
}

class _OkSetup extends TaxiSetupController {
  _OkSetup(this.ok);
  final bool ok;

  @override
  Future<bool> saveRoutes(List<Map<String, dynamic>> routes, {bool quietLimit = false}) async => ok;
}

Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(seconds: 6));
}

_CountPlan _plan(MyPlanModel p) => Get.put<PlanController>(_CountPlan(p)) as _CountPlan;

void main() {
  setUpAll(() => initTestStorage('taxi_plan_fix_hub'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  test('ended copy says the last added route stays (server keeps the newest)', () {
    expect(TaxiPlanStrings.lastRouteStays, 'Your last added route stays. Extra routes are hidden, not deleted.');
    final v = PlanValues.fromCatalog([freePlan('Taxi'), plusPlan('Taxi')]);
    expect(const TaxiPlanCopy().heroMeter(PlanCardState.ended, Fx.ended('Taxi'), v)!.notes, [TaxiPlanStrings.lastRouteStays]);
  });

  testWidgets('deleting a hidden route refreshes /plans/me once', (t) async {
    final c = hubFor(taxiJson(hidden: 1), deleteRouteCall: (_) async => OwnerOk<void>(null));
    final plan = _plan(OwnerPlans.free);
    await pumpPhone(t, const SizedBox.shrink(), toastHost: true);
    await t.runAsync(() => c.deleteHiddenRoute('r1'));
    await _settle(t);
    expect(plan.invalidates, 1);
    await _close(t);
  });

  testWidgets('a refused hidden route delete does not refresh /plans/me', (t) async {
    final c = hubFor(taxiJson(hidden: 1), deleteRouteCall: (_) async => const OwnerRefused<void>(type: 'Busy', statusCode: 409, message: 'No'));
    final plan = _plan(OwnerPlans.free);
    await pumpPhone(t, const SizedBox.shrink(), toastHost: true);
    await t.runAsync(() => c.deleteHiddenRoute('r1'));
    await _settle(t);
    expect(plan.invalidates, 0);
    await _close(t);
  });

  testWidgets('L15 a refused hidden route delete (a re-buy restored it) reloads the hub so the inactive card goes', (t) async {
    hubFor(taxiJson(hidden: 1));
    Get.delete<TaxiHubController>(tag: TaxiHubController.tag, force: true);
    var fetches = 0;
    final c = Get.put(
      TaxiHubController(
        userId: () => 'user-a',
        fetch: () async {
          fetches++;
          return {'data': taxiJson(routes: 1)};
        },
        deleteRouteCall: (_) async => const OwnerRefused<void>(type: 'BadRequest', statusCode: 400, message: 'This route is active again.'),
      ),
      tag: TaxiHubController.tag,
    );
    _plan(OwnerPlans.plus);
    await pumpPhone(t, const SizedBox.shrink(), toastHost: true);
    await t.runAsync(() => c.reload());
    final before = fetches;
    final ok = await t.runAsync(() => c.deleteHiddenRoute('r1'));
    await _settle(t);
    expect(ok, isFalse);
    expect(fetches, greaterThan(before));
    await _close(t);
  });

  testWidgets('a hub route save refreshes /plans/me only when it worked', (t) async {
    final c = hubFor(taxiJson(routes: 1));
    final plan = _plan(OwnerPlans.free);
    Get.put<TaxiSetupController>(_OkSetup(true));
    await pumpPhone(t, const SizedBox.shrink(), toastHost: true);
    await t.runAsync(() => c.saveRoutes(const [], 'Saved'));
    await _settle(t);
    expect(plan.invalidates, 1);
    Get.delete<TaxiSetupController>(force: true);
    Get.put<TaxiSetupController>(_OkSetup(false));
    await t.runAsync(() => c.saveRoutes(const [], 'Saved'));
    await _settle(t);
    expect(plan.invalidates, 1);
    await _close(t);
  });

  group('manage Add calm line', () {
    Future<void> open(WidgetTester t, Map<String, dynamic> json, MyPlanModel plan) async {
      final c = hubFor(json, plan: plan);
      await c.reload();
      await t.pumpWidget(const SizedBox.shrink());
      await pumpPhone(t, const TaxiRoutesScreen(manage: true), size: const Size(392, 1400), toastHost: true);
      await _settle(t);
    }

    const line = ValueKey('routes_manage_full_line');

    testWidgets('Plus 5 of 5: grey line says the cap', (t) async {
      await open(t, taxiJson(routes: 5), OwnerPlans.plus);
      expect(find.byKey(line), findsOneWidget);
      expect(find.text('You can add up to 5 routes.'), findsOneWidget);
      await _close(t);
    });

    testWidgets('Plus 2 of 5: no line', (t) async {
      await open(t, taxiJson(routes: 2), OwnerPlans.plus);
      expect(find.byKey(line), findsNothing);
      await _close(t);
    });

    testWidgets('Free 1 of 1 can upgrade: no line (Add opens the Plus sheet)', (t) async {
      await open(t, taxiJson(), OwnerPlans.free);
      expect(find.byKey(line), findsNothing);
      await _close(t);
    });
  });
}
