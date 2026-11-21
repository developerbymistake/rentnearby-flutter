import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/stay_owner/hub/stay_hub_controller.dart';
import 'package:bakhli/features/stay_owner/hub/stay_hub_screen.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_render.dart';
import 'stay_fixtures.dart';

StayHubController hubFor(Map<String, dynamic>? stay, {MyPlanModel plan = OwnerPlans.free}) {
  Get.reset();
  Get.testMode = true;
  Get.put<TabConfigController>(FakeTabs());
  final auth = FakeAuth();
  Get.put<AuthController>(auth);
  auth.signIn(role: 'STAY_OWNER', stayStatus: 'Approved');
  PlanGate.debugPlan = plan;
  return Get.put(StayHubController(userId: () => 'user-a', fetch: () async => {'data': stay}), tag: StayHubController.tag);
}

void main() {
  setUpAll(() => initTestStorage('stay_hub_render'));
  useOwnerRenderScale();
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  Future<void> settle(WidgetTester t) async {
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));
  }

  testWidgets('render o_st_13', (tester) async {
    final c = hubFor(stayJson());
    await renderOwnerFrame(tester, 'o_st_13', StayHubScreen(root: true, controller: c), arrange: settle);
  });

  testWidgets('render o_st_14', (tester) async {
    final c = hubFor(
      stayJson(
        rooms: 4,
        photos: 6,
        featured: true,
        meters: [{'key': 'Photos', 'used': 6, 'limit': 8}, {'key': 'RoomTypes', 'used': 4, 'limit': 6}],
        specialPricesRow: {
          'count': 4,
          'limit': 5,
          'first': {'label': 'Diwali week', 'dateFrom': '2026-11-06', 'dateTo': '2026-11-12', 'direction': 'Higher', 'percent': 20},
        },
      ),
      plan: OwnerPlans.plus,
    );
    await renderOwnerFrame(tester, 'o_st_14', StayHubScreen(root: true, controller: c), arrange: settle);
  });

  testWidgets('render o_st_15', (tester) async {
    final c = hubFor(stayJson());
    await renderOwnerFrame(tester, 'o_st_15', StayHubScreen(root: true, controller: c), arrange: (t) async {
      await settle(t);
      await t.tap(find.text('Edit price').first);
      await settle(t);
    });
  });

  testWidgets('render o_st_63 A', (tester) async {
    final c = hubFor(stayJson(confirmed: 2));
    await renderOwnerFrame(tester, 'o_st_63', StayHubScreen(root: true, controller: c), part: 'A', arrange: (t) async {
      await settle(t);
      await t.ensureVisible(find.text('Delete stay'));
      await t.tap(find.text('Delete stay'));
      await settle(t);
    });
  });

  testWidgets('render o_st_63 B', (tester) async {
    final c = hubFor(null);
    await renderOwnerFrame(tester, 'o_st_63', StayHubScreen(root: true, controller: c), part: 'B', arrange: settle);
  });

  for (final e in {
    'A': stayJson(pendingEdit: {'fields': {'name': 'Deodar Heights Mountain Homestay'}, 'at': '2026-11-21T10:00:00Z'}, rooms: 2),
    'B': stayJson(name: 'Deodar Heights Mountain Homestay', lastEditResult: {'result': 'Approved', 'reason': null, 'at': '2026-11-21T10:00:00Z', 'fieldsChanged': ['name']}),
    'C': stayJson(lastEditResult: {'result': 'Rejected', 'reason': 'the name must match your registration', 'at': '2026-11-21T10:00:00Z', 'fieldsChanged': ['name']}),
  }.entries) {
    testWidgets('render o_st_64 ${e.key}', (tester) async {
      final c = hubFor(e.value);
      await renderOwnerFrame(tester, 'o_st_64', StayHubScreen(root: true, controller: c), part: e.key, arrange: settle);
    });
  }
}
