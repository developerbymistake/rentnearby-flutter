import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/owner_core/data/owner_args.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/plan/owner_inactive.dart';
import 'package:bakhli/features/owner_core/plan/owner_manage_card.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/taxi/setup/taxi_routes_screen.dart';
import 'package:bakhli/features/taxi_driver/hub/taxi_hub_controller.dart';
import 'package:bakhli/features/taxi_driver/hub/taxi_hub_screen.dart';
import 'package:bakhli/features/taxi_driver/strings/taxi_gate_strings.dart';
import 'package:bakhli/features/taxi_driver/widgets/taxi_widgets.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/real_phone.dart';
import '../core/taxi_fixtures.dart';

Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 400));
}

Future<TaxiHubController> _open(WidgetTester t, Map<String, dynamic> json, {MyPlanModel plan = OwnerPlans.free, Future<OwnerResult<void>> Function(String id)? deleteRouteCall}) async {
  final c = hubFor(json, plan: plan, deleteRouteCall: deleteRouteCall);
  await c.reload();
  await t.pumpWidget(const SizedBox.shrink());
  await pumpPhone(t, const TaxiRoutesScreen(manage: true), size: const Size(392, 1400), toastHost: true);
  await _settle(t);
  return c;
}

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(seconds: 6));
}

GradientPillButton _add(WidgetTester t) => t.widget<GradientPillButton>(find.descendant(of: find.byKey(const ValueKey('routes_manage_add')), matching: find.byType(GradientPillButton)));

void main() {
  setUpAll(() => initTestStorage('taxi_routes_manage'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  test('manage flag comes from the route arguments', () {
    expect(OwnerArgs.isManage(OwnerArgs.manage), isTrue);
    expect(OwnerArgs.isManage(null), isFalse);
    expect(TaxiGateStrings.routeInactive(1), 'Inactive: the Free plan allows 1 route.');
    expect(TaxiGateStrings.routeInactive(5), 'Inactive: the Free plan allows 5 routes.');
  });

  testWidgets('Free 1 of 1: strip, one card with three pills, Add route opens the Plus sheet', (t) async {
    await _open(t, taxiJson());
    expect(find.text('1 of 1 routes used'), findsOneWidget);
    expect(find.byKey(GateKeys.planStrip), findsOneWidget);
    expect(find.byType(OwnerManageCard), findsOneWidget);
    for (final s in ['ROUTE 1', 'One way', 'Haldwani to Nainital', 'Fare ₹1,800', 'Edit fare', 'Edit route', 'Delete']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.text('Local sightseeing'), findsNothing);
    expect(_add(t).enabled, isTrue);
    await t.ensureVisible(find.text('Add route'));
    await t.tap(find.text('Add route'));
    await _settle(t);
    expect(find.byKey(GateKeys.sheet), findsOneWidget);
    expect(find.text('Save route'), findsNothing);
    await _close(t);
  });

  testWidgets('Plus 2 of 5: no strip, Add route opens the inline form', (t) async {
    await _open(t, taxiJson(routes: 2), plan: OwnerPlans.plus);
    expect(find.byKey(GateKeys.planStrip), findsNothing);
    expect(find.text('2 of 5 routes used'), findsOneWidget);
    await t.ensureVisible(find.text('Add route'));
    await t.tap(find.text('Add route'));
    await _settle(t);
    expect(find.byKey(GateKeys.sheet), findsNothing);
    expect(find.text('Save route'), findsOneWidget);
    await _close(t);
  });

  testWidgets('Plus 5 of 5: Add route is greyed', (t) async {
    await _open(t, taxiJson(routes: 5), plan: OwnerPlans.plus);
    expect(find.byType(OwnerManageCard), findsNWidgets(5));
    expect(_add(t).enabled, isFalse);
    await _close(t);
  });

  testWidgets('after Plus: an INACTIVE route card with one reason line, greyed edits, Delete and Choose your route', (t) async {
    final deleted = <String>[];
    await _open(t, taxiJson(hidden: 1), deleteRouteCall: (id) async {
      deleted.add(id);
      return OwnerOk<void>(null);
    });
    final inactive = find.byType(OwnerInactiveCard);
    expect(inactive, findsOneWidget);
    expect(find.descendant(of: inactive, matching: find.text('INACTIVE')), findsOneWidget);
    expect(find.descendant(of: inactive, matching: find.text('Inactive: the Free plan allows 1 route.')), findsOneWidget);
    expect(t.widget<WhitePillButton>(find.descendant(of: inactive, matching: find.widgetWithText(WhitePillButton, 'Edit fare'))).enabled, isFalse);
    expect(find.text('Choose your route'), findsOneWidget);
    await t.ensureVisible(find.descendant(of: inactive, matching: find.text('Delete')));
    await t.tap(find.descendant(of: inactive, matching: find.text('Delete')));
    await _settle(t);
    expect(deleted, ['r1']);
    await _close(t);
  });

  testWidgets('routes not loaded: no Add route and no empty list until /taxis/me loads (full replace guard)', (t) async {
    hubFor(taxiJson());
    Get.delete<TaxiHubController>(tag: TaxiHubController.tag, force: true);
    var fail = true;
    final c = Get.put(
      TaxiHubController(
        userId: () => 'user-a',
        fetch: () async {
          if (fail) throw Exception('offline');
          return {'data': taxiJson(routes: 2)};
        },
      ),
      tag: TaxiHubController.tag,
    );
    await c.reload();
    expect(c.taxi, isNull);
    await t.pumpWidget(const SizedBox.shrink());
    await pumpPhone(t, const TaxiRoutesScreen(manage: true), size: const Size(392, 1400), toastHost: true);
    await _settle(t);
    expect(find.byKey(const ValueKey('routes_manage_state')), findsOneWidget);
    expect(find.byKey(const ValueKey('routes_manage_add')), findsNothing);
    expect(find.text('Save route'), findsNothing);
    fail = false;
    await t.tap(find.text('Try again'));
    await _settle(t);
    expect(find.byKey(const ValueKey('routes_manage_state')), findsNothing);
    expect(find.byType(OwnerManageCard), findsNWidgets(2));
    expect(find.byKey(const ValueKey('routes_manage_add')), findsOneWidget);
    await _close(t);
  });

  testWidgets('My Taxi: one Your routes row, bold headings with a count, Delete taxi row, no Share', (t) async {
    final c = hubFor(taxiJson(routes: 2));
    await t.pumpWidget(const SizedBox.shrink());
    await pumpPhone(t, TaxiHubScreen(root: true, controller: c), size: const Size(392, 2400), toastHost: true);
    await _settle(t);
    expect(find.text('Routes and fares'), findsOneWidget);
    expect(find.text('2 routes'), findsOneWidget);
    expect(find.text('Your routes'), findsOneWidget);
    expect(find.text('Haldwani to Nainital and 1 more · from ₹1,800'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Edit fare'), findsNothing);
    expect(find.text('Share'), findsNothing);
    for (final s in ['Local sightseeing', 'Photos', 'Taxi details', 'Remove this listing', 'Local day', 'From']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.byType(TaxiDeleteRow), findsOneWidget);
    await _close(t);
  });
}
