import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/taxi/setup/taxi_routes_screen.dart';
import 'package:bakhli/features/taxi_driver/hub/taxi_hub_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/owner_render.dart';
import 'taxi_fixtures.dart';

void main() {
  setUpAll(() => initTestStorage('taxi_hub_render'));
  useOwnerRenderScale();
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  Future<void> settle(WidgetTester t) async {
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 400));
  }

  testWidgets('render o_tx_17', (tester) async {
    final c = hubFor(taxiJson(routesMeter: {'key': 'Routes', 'used': 1, 'limit': 1}));
    await renderOwnerFrame(tester, 'o_tx_17', TaxiHubScreen(root: true, controller: c), arrange: settle);
  });

  testWidgets('render o_tx_18', (tester) async {
    final c = hubFor(taxiJson(routes: 5, featured: true), plan: OwnerPlans.plus);
    await renderOwnerFrame(tester, 'o_tx_18', TaxiHubScreen(root: true, controller: c), arrange: settle);
  });

  testWidgets('render o_tx_19', (tester) async {
    final c = hubFor(taxiJson());
    await c.reload();
    await renderOwnerFrame(tester, 'o_tx_19', const TaxiRoutesScreen(manage: true), arrange: (t) async {
      await settle(t);
      await t.tap(find.text('Edit fare').first);
      await settle(t);
    });
  });

  testWidgets('render o_tx_41 A', (tester) async {
    final c = hubFor(taxiJson());
    await c.reload();
    await renderOwnerFrame(tester, 'o_tx_41', const TaxiRoutesScreen(manage: true), part: 'A', arrange: (t) async {
      await settle(t);
      await t.tap(find.text('Edit route').first);
      await settle(t);
    });
  });

  testWidgets('render o_tx_41 B', (tester) async {
    final c = hubFor(taxiJson(routes: 3), plan: OwnerPlans.plus);
    await c.reload();
    await renderOwnerFrame(tester, 'o_tx_41', const TaxiRoutesScreen(manage: true), part: 'B', arrange: (t) async {
      await settle(t);
      await t.tap(find.text('Delete').first);
      await settle(t);
    });
  });

  testWidgets('render o_tx_41 C', (tester) async {
    final c = hubFor(taxiJson());
    await c.reload();
    await renderOwnerFrame(tester, 'o_tx_41', const TaxiRoutesScreen(manage: true), part: 'C', arrange: settle);
  });

  testWidgets('render o_tx_41 D', (tester) async {
    final c = hubFor(taxiJson());
    await renderOwnerFrame(tester, 'o_tx_41', TaxiHubScreen(root: true, controller: c), part: 'D', arrange: (t) async {
      await settle(t);
      await t.ensureVisible(find.text('Edit').first);
      await t.tap(find.text('Edit').first);
      await settle(t);
    });
  });

  testWidgets('render o_tx_44 A', (tester) async {
    final c = hubFor(taxiJson(bookings: 1));
    await renderOwnerFrame(tester, 'o_tx_44', TaxiHubScreen(root: true, controller: c), part: 'A', arrange: (t) async {
      await settle(t);
      await t.ensureVisible(find.text('Delete taxi'));
      await t.tap(find.text('Delete taxi'));
      await settle(t);
    });
  });

  testWidgets('render o_tx_44 C', (tester) async {
    final c = hubFor(null);
    await renderOwnerFrame(tester, 'o_tx_44', TaxiHubScreen(root: true, controller: c), part: 'C', arrange: settle);
  });
}
