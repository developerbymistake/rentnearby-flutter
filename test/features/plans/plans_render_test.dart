import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/taxi_driver/plan_visible/choose_route_controller.dart';
import 'package:bakhli/features/taxi_driver/plan_visible/taxi_plan_visible_screen.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/screens/plans_billing_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/owner_fakes.dart';
import '../../support/owner_render.dart';
import 'plans_harness.dart';

void main() {
  useOwnerRenderScale();
  setUpAll(() => initTestStorage('plans_render'));
  tearDown(resetPlans);

  Future<void> render(WidgetTester t, String name, MyPlanModel me, double h, {bool trial = true}) async {
    installPlans(me, trialOffer_: trial);
    await renderPlanFrame(t, name, const PlansBillingScreen(), height: h);
    expect(t.takeException(), isNull);
  }

  testWidgets('render o_pl_1', (t) => render(t, 'o_pl_1', Fx.free('Taxi'), planFrameHeights['o_pl_1']!));
  testWidgets('render o_pl_2', (t) => render(t, 'o_pl_2', Fx.free('Stay'), planFrameHeights['o_pl_2']!));
  testWidgets('render o_pl_3', (t) => render(t, 'o_pl_3', Fx.trial('Taxi'), planFrameHeights['o_pl_3']!));
  testWidgets('render o_pl_4', (t) async {
    final auth = FakeAuth();
    Get.put<AuthController>(auth);
    auth.signIn(role: 'STAY_OWNER', stayStatus: 'Approved');
    OwnerCache.write('user-a', OwnerCacheKeys.home, {
      'planCard': {
        'state': 'Plus',
        'weekly': {'shown': 412, 'enquiries': 9},
      },
    });
    await render(t, 'o_pl_4', Fx.plus('Stay'), planFrameHeights['o_pl_4']!);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('412'), findsOneWidget);
    expect(find.text('Times shown'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('Enquiries'), findsOneWidget);
    OwnerCache.remove('user-a', OwnerCacheKeys.home);
  });
  testWidgets('render o_pl_5', (t) => render(t, 'o_pl_5', Fx.cancelled('Taxi'), planFrameHeights['o_pl_5']!));
  testWidgets('render o_pl_6', (t) => render(t, 'o_pl_6', Fx.grace('Stay'), planFrameHeights['o_pl_6']!));
  testWidgets('render o_pl_7', (t) => render(t, 'o_pl_7', Fx.onHold('Taxi'), planFrameHeights['o_pl_7']!));
  testWidgets('render o_pl_8', (t) => render(t, 'o_pl_8', Fx.ended('Taxi'), planFrameHeights['o_pl_8']!, trial: false));
  testWidgets('render o_pl_9', (t) => render(t, 'o_pl_9', Fx.off('Taxi'), planFrameHeights['o_pl_9']!));
  testWidgets('render o_pl_15_a', (t) => render(t, 'o_pl_15_a', Fx.trial('Stay'), 700));
  testWidgets('render o_pl_15_b', (t) => render(t, 'o_pl_15_b', Fx.cancelled('Stay'), 700));
  testWidgets('render o_pl_15_c', (t) => render(t, 'o_pl_15_c', Fx.onHold('Stay'), 700));
  testWidgets('render o_tx_45_b', (t) async {
    PlanGate.debugPlan = const MyPlanModel(paymentEnabled: true, limits: PlanLimitsModel(routes: 1));
    Map<String, dynamic> r(String id, int i, String to, int fare) => {'id': id, 'routeIndex': i, 'fromName': 'Haldwani', 'toName': to, 'fare': fare, 'tripType': 'OneWay'};
    final api = _RouteApi({
      'routes': [r('a', 1, 'Nainital', 1800)],
      'hiddenRoutes': [r('b', 2, 'Ranikhet', 3000), r('c', 3, 'Mukteshwar', 2600), r('d', 4, 'Kausani', 3800)],
    });
    final c = Get.put(ChooseRouteController(api: api, userId: () => null), tag: ChooseRouteController.tag);
    await renderOwnerFrame(t, 'o_tx_45', TaxiPlanVisibleScreen(controller: c), part: 'B');
    expect(t.takeException(), isNull);
  });
  testWidgets('render o_pl_15_d', (t) => render(t, 'o_pl_15_d', Fx.ended('Stay'), 700, trial: false));
}

class _RouteApi extends ChooseRouteApi {
  _RouteApi(this.data);
  final Map<String, dynamic> data;
  @override
  Future<OwnerResult<Map<String, dynamic>>> load() async => OwnerOk(data);
}
