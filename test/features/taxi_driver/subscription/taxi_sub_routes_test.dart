import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/owner_core/data/owner_cache.dart';
import 'package:bakhli/features/owner_core/data/owner_result.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/features/owner_core/plan/owner_inactive.dart';
import 'package:bakhli/features/owner_core/plan/owner_manage_card.dart';
import 'package:bakhli/features/owner_core/plan/plan_gate.dart';
import 'package:bakhli/features/taxi/setup/taxi_routes_screen.dart';
import 'package:bakhli/features/taxi_driver/strings/taxi_gate_strings.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/owner_fakes.dart';
import '../../../support/real_phone.dart';
import '../core/taxi_fixtures.dart';

// Matrix L1-L16 for the Taxi routes page (Manage routes): one plan model per lifecycle state, same screen.

const _paid = MyPlanModel(paymentEnabled: true, isPaid: true, isDefault: false, limits: OwnerPlans.plusLimits);
const _cancelled = MyPlanModel(paymentEnabled: true, isPaid: true, isDefault: false, limits: OwnerPlans.plusLimits, state: 'Cancelled');
const _grace = MyPlanModel(paymentEnabled: true, isPaid: true, isDefault: false, limits: OwnerPlans.plusLimits, state: 'Grace');
const _onHold = MyPlanModel(paymentEnabled: true, state: 'OnHold');
const _ended = MyPlanModel(paymentEnabled: true, state: 'Ended');

const _fullLine = ValueKey('routes_manage_full_line');

Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> _open(WidgetTester t, Map<String, dynamic> json, MyPlanModel plan, {Future<OwnerResult<void>> Function(String id)? deleteRouteCall}) async {
  final c = hubFor(json, plan: plan, deleteRouteCall: deleteRouteCall);
  await c.reload();
  await t.pumpWidget(const SizedBox.shrink());
  await pumpPhone(t, const TaxiRoutesScreen(manage: true), size: const Size(392, 2600), toastHost: true);
  await _settle(t);
}

Future<void> _close(WidgetTester t) async {
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump(const Duration(seconds: 6));
}

// An inactive route is an OwnerInactiveCard, which draws a muted OwnerManageCard inside it.
Finder get _activeCards => find.byWidgetPredicate((w) => w is OwnerManageCard && !w.muted);

GradientPillButton _add(WidgetTester t) => t.widget<GradientPillButton>(find.descendant(of: find.byKey(const ValueKey('routes_manage_add')), matching: find.byType(GradientPillButton)));

Future<void> _tapAdd(WidgetTester t) async {
  await t.ensureVisible(find.text('Add route'));
  await t.tap(find.text('Add route'));
  await _settle(t);
}

void main() {
  setUpAll(() => initTestStorage('taxi_sub_routes'));
  setUp(OwnerCache.clearAll);
  tearDown(() {
    PlanGate.debugPlan = null;
    resetOwnerTestState();
  });

  for (final (name, plan) in [('Trial (L11)', OwnerPlans.trial), ('Plus (L3)', _paid), ('Cancelled, still running (L5)', _cancelled), ('Grace (L7)', _grace), ('Admin grant', OwnerPlans.grant)]) {
    testWidgets('$name, 2 of 5: no strip, Add enabled, Add opens the inline form', (t) async {
      await _open(t, taxiJson(routes: 2), plan);
      expect(find.byKey(GateKeys.planStrip), findsNothing);
      expect(find.byType(OwnerInactiveCard), findsNothing);
      expect(find.text('2 of 5 routes used'), findsOneWidget);
      expect(_add(t).enabled, isTrue);
      await _tapAdd(t);
      expect(find.byKey(GateKeys.sheet), findsNothing);
      expect(find.text('Save route'), findsOneWidget);
      await _close(t);
    });

    testWidgets('$name, 5 of 5 (L4): Add greyed, one calm line, no Plus sheet', (t) async {
      await _open(t, taxiJson(routes: 5), plan);
      expect(find.byType(OwnerManageCard), findsNWidgets(5));
      expect(_add(t).enabled, isFalse);
      expect(find.byKey(_fullLine), findsOneWidget);
      expect(find.text(TaxiGateStrings.upTo(5)), findsOneWidget);
      expect(find.byKey(GateKeys.planStrip), findsNothing);
      await t.tap(find.text('Add route'), warnIfMissed: false);
      await _settle(t);
      expect(find.byKey(GateKeys.sheet), findsNothing);
      expect(find.text('Save route'), findsNothing);
      await _close(t);
    });
  }

  for (final (name, count, enabled) in [('payment OFF (L14), 1 route', 1, true), ('payment OFF (L14), 5 routes', 5, false)]) {
    testWidgets('$name: nothing inactive, no strip, no sheet, Add ${enabled ? 'opens the form' : 'is greyed'}', (t) async {
      await _open(t, taxiJson(routes: count), OwnerPlans.paymentOff);
      expect(find.byKey(GateKeys.planStrip), findsNothing);
      expect(find.byType(OwnerInactiveCard), findsNothing);
      expect(_add(t).enabled, enabled);
      if (enabled) {
        await _tapAdd(t);
        expect(find.byKey(GateKeys.sheet), findsNothing);
        expect(find.text('Save route'), findsOneWidget);
      } else {
        expect(find.byKey(_fullLine), findsOneWidget);
      }
      await _close(t);
    });
  }

  for (final (name, plan) in [('Expired (L6)', _ended), ('Refund or revoke (L10)', _ended), ('Trial ended (L11)', _ended), ('On hold (L8)', _onHold), ('Free, never paid', OwnerPlans.free)]) {
    testWidgets('$name with 3 extra routes: three inactive cards with one reason line each, Delete, Choose your route', (t) async {
      await _open(t, taxiJson(hidden: 3), plan);
      expect(find.byType(OwnerInactiveCard), findsNWidgets(3));
      expect(find.text('INACTIVE'), findsNWidgets(3));
      expect(find.text(TaxiGateStrings.routeInactive(1)), findsNWidgets(3));
      expect(_activeCards, findsOneWidget, reason: 'the kept route stays active');
      expect(find.text('Choose your route'), findsOneWidget);
      expect(find.byKey(GateKeys.planStrip), findsOneWidget);
      expect(_add(t).enabled, isTrue);
      await _close(t);
    });

    testWidgets('$name: Add route at 1 of 1 opens the Plus sheet, not the form', (t) async {
      await _open(t, taxiJson(hidden: 3), plan);
      await _tapAdd(t);
      expect(find.byKey(GateKeys.sheet), findsOneWidget);
      expect(find.text('Save route'), findsNothing);
      await _close(t);
    });
  }

  testWidgets('L9 re-subscribe: the same routes come back active, nothing duplicated, no Choose, Add up to Plus', (t) async {
    await _open(t, taxiJson(hidden: 3), _ended);
    expect(find.byType(OwnerInactiveCard), findsNWidgets(3));
    await _close(t);
    await _open(t, taxiJson(routes: 4), _paid);
    expect(find.byType(OwnerInactiveCard), findsNothing);
    expect(find.text('INACTIVE'), findsNothing);
    expect(find.text('Choose your route'), findsNothing);
    expect(find.byType(OwnerManageCard), findsNWidgets(4));
    for (final to in ['Nainital', 'Mukteshwar', 'Almora', 'Ranikhet']) {
      expect(find.text('Haldwani to $to'), findsOneWidget, reason: to);
    }
    expect(find.byKey(GateKeys.planStrip), findsNothing);
    expect(find.text('4 of 5 routes used'), findsOneWidget);
    expect(_add(t).enabled, isTrue);
    await _close(t);
  });

  testWidgets('L3 buy Plus from Free 1 of 1: Add opens the sheet before, the form after', (t) async {
    await _open(t, taxiJson(), OwnerPlans.free);
    await _tapAdd(t);
    expect(find.byKey(GateKeys.sheet), findsOneWidget);
    await _close(t);
    await _open(t, taxiJson(), _paid);
    expect(find.byKey(GateKeys.planStrip), findsNothing);
    expect(_add(t).enabled, isTrue);
    await _tapAdd(t);
    expect(find.byKey(GateKeys.sheet), findsNothing);
    expect(find.text('Save route'), findsOneWidget);
    await _close(t);
  });

  testWidgets('L6 expire from Plus 5 of 5 to Free: Add turns from greyed to the Plus sheet', (t) async {
    await _open(t, taxiJson(routes: 5), _paid);
    expect(_add(t).enabled, isFalse);
    await _close(t);
    await _open(t, taxiJson(hidden: 4), _ended);
    expect(_activeCards, findsOneWidget);
    expect(find.byType(OwnerInactiveCard), findsNWidgets(4));
    expect(find.byKey(_fullLine), findsNothing);
    expect(_add(t).enabled, isTrue);
    await _close(t);
  });

  testWidgets('delete of an inactive route refused with PlanRowInactive: card stays, one call, no crash', (t) async {
    final calls = <String>[];
    await _open(t, taxiJson(hidden: 1), _ended, deleteRouteCall: (id) async {
      calls.add(id);
      return const OwnerRefused<void>(type: 'PlanRowInactive', statusCode: 409, message: 'This route is inactive.');
    });
    final del = find.descendant(of: find.byType(OwnerInactiveCard), matching: find.text('Delete'));
    await t.ensureVisible(del);
    await t.tap(del);
    await _settle(t);
    expect(calls, ['r1']);
    expect(find.byType(OwnerInactiveCard), findsOneWidget);
    await _close(t);
  });

  testWidgets('delete of an inactive route while offline: card stays, Delete usable again', (t) async {
    var n = 0;
    await _open(t, taxiJson(hidden: 1), _ended, deleteRouteCall: (id) async {
      n++;
      return const OwnerOffline<void>();
    });
    final del = find.descendant(of: find.byType(OwnerInactiveCard), matching: find.text('Delete'));
    await t.ensureVisible(del);
    await t.tap(del);
    await _settle(t);
    await t.tap(del, warnIfMissed: false);
    await _settle(t);
    expect(n, 2, reason: 'busy flag cleared after the failure');
    expect(find.byType(OwnerInactiveCard), findsOneWidget);
    await _close(t);
  });

  test('route copy: Free and Plus numbers follow the plan, never a fixed number', () {
    PlanGate.debugPlan = OwnerPlans.free;
    expect(TaxiGateStrings.freeRoutes, 1);
    expect(TaxiGateStrings.routeInactive(TaxiGateStrings.freeRoutes), 'Inactive: the Free plan allows 1 route.');
    expect(TaxiGateStrings.routeGate().title, '1 route on Free');
    PlanGate.debugPlan = _paid;
    expect(TaxiGateStrings.freeRoutes, 5);
    expect(TaxiGateStrings.upTo(5), 'You can add up to 5 routes.');
    expect(TaxiGateStrings.routesCount(1), '1 route');
    expect(TaxiGateStrings.moreRoutes(1), '1 more route');
  });
}
