import 'package:bakhli/design/extra/ext_plans.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/screens/plans_billing_screen.dart';
import 'package:bakhli/widgets/plan_cycle_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/real_phone.dart';
import 'plans_harness.dart';

Future<void> _pump(WidgetTester t, MyPlanModel me) async {
  installPlans(me);
  await pumpPhone(t, const PlansBillingScreen(), size: const Size(392, 3200));
  await settlePhone(t);
  await settlePhone(t);
}

MyPlanModel _grantWhileOff(String key) => MyPlanModel(
      paymentEnabled: false,
      featureKey: key,
      planName: 'Plus',
      isDefault: false,
      isPaid: true,
      source: 'AdminGrant',
      endsAt: renewDate,
      daysLeft: 29,
      limits: key == 'Taxi' ? taxiPlusLimits : stayPlusLimits,
    );

// A plan with no Google Play subscription (revoked grant, payment just turned on): Free limits, rows hidden.
MyPlanModel _freeHidden(String key, PlanHiddenModel hidden, {int paused = 0}) => MyPlanModel(
      paymentEnabled: true,
      featureKey: key,
      limits: key == 'Taxi' ? taxiFreeLimits : stayFreeLimits,
      usage: key == 'Taxi' ? const PlanUsageModel(routes: 1) : const PlanUsageModel(photos: 2, roomTypes: 2),
      hidden: hidden,
      pausedByPlanCount: paused,
    );

void main() {
  tearDown(resetPlans);

  group('FX-13 admin grant while payment is OFF', () {
    for (final key in ['Taxi', 'Stay']) {
      testWidgets('$key: the grant hero with its end date, not "Paid plans are coming"', (t) async {
        await _pump(t, _grantWhileOff(key));
        expect(find.textContaining('Ends 21 Dec 2026'), findsWidgets);
        expect(find.textContaining('29 days left'), findsWidgets);
        expect(find.text('Active'), findsWidgets);
        expect(find.textContaining('Paid plans are coming'), findsNothing);
        expect(find.textContaining('Free for now'), findsNothing);
        expect(find.byType(PlanCycleOption), findsNothing);
        expect(find.byType(PlanBar3D), findsNothing);
      });
    }
  });

  group('FX-15 the choose action follows what is hidden, in every state', () {
    testWidgets('stay with hidden photos and no subscription: Choose what stays', (t) async {
      await _pump(t, _freeHidden('Stay', const PlanHiddenModel(photos: 3)));
      expect(find.text('Choose what stays'), findsOneWidget);
      expect(find.text('Special prices'), findsNothing);
    });

    testWidgets('taxi with hidden routes and no subscription: Choose your route', (t) async {
      await _pump(t, _freeHidden('Taxi', const PlanHiddenModel(routes: 2)));
      expect(find.text('Choose your route'), findsOneWidget);
    });

    testWidgets('stay with only special prices paused: Special prices, not Choose what stays', (t) async {
      await _pump(t, _freeHidden('Stay', const PlanHiddenModel(specialPrices: 2)));
      expect(find.text('Special prices'), findsOneWidget);
      expect(find.text('Choose what stays'), findsNothing);
    });

    testWidgets('nothing hidden: no choose action (it would open an empty screen)', (t) async {
      await _pump(t, _freeHidden('Stay', const PlanHiddenModel()));
      expect(find.text('Choose what stays'), findsNothing);
      expect(find.text('Special prices'), findsNothing);
      await _pump(t, _freeHidden('Taxi', const PlanHiddenModel(), paused: 3));
      expect(find.text('Choose your route'), findsNothing);
    });
  });
}
