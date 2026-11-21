import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/design/extra/ext_plans.dart';
import 'package:bakhli/features/owner_core/plan/gate_keys.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/models/plan_model.dart';
import 'package:bakhli/screens/plans_billing_screen.dart';
import 'package:bakhli/widgets/plan_cycle_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/owner_sizes.dart';
import '../../support/real_phone.dart';
import 'plans_harness.dart';

Future<void> _pump(WidgetTester t, MyPlanModel me, {bool trialOffer = true, double h = 3200, double w = 392, Map<String, int>? plusFeatures}) async {
  installPlans(me, trialOffer_: trialOffer, plusFeatures: plusFeatures);
  await pumpPhone(t, const PlansBillingScreen(), size: Size(w, h));
  await settlePhone(t);
  await settlePhone(t);
}

void _has(List<String> texts) {
  for (final s in texts) {
    expect(find.textContaining(s), findsWidgets, reason: s);
  }
}

void _not(List<String> texts) {
  for (final s in texts) {
    expect(find.textContaining(s), findsNothing, reason: s);
  }
}

Finder get _bar => find.byType(PlanBar3D);

void main() {
  tearDown(resetPlans);

  group('o_pl_1 taxi Free', () {
    testWidgets('every string of the frame', (t) async {
      await _pump(t, Fx.free('Taxi'));
      _has([
        'Plans & Billing', 'Taxi plan', 'History', 'Your plan', 'Free', 'No end date', '1 route', 'Normal turn for requests',
        'Routes', '1 of 1', 'Free plan: 1 route. Plus allows up to 5.', 'What you get', 'Free vs Plus', 'BEST',
        'Your turn for requests', 'Normal', '2x', 'Featured in taxi lists', 'Requests, bookings, rating', 'Upcoming list', '15 days',
        '6 months', 'Month calendar', 'This month', '+6 months', 'Trips you add', '50', 'Morning reminder', 'Month money summary',
        'Money notes on each trip', 'Pick how long', 'Auto-renews. Cancel anytime in Google Play.', '1 month', '₹150', '₹150 / mo',
        'Billed monthly', '3 months', '₹133', 'Save 11%', 'Billed ₹400 every 3 months', '12 months', '₹117', 'Save 22%',
        'Billed ₹1,400 a year', 'Have a coupon?', 'Restore purchases', 'Plus · 1 month', '₹150 today', 'Continue with Plus',
        'Try free for 7 days', 'Then ₹150/month. Cancel anytime in Google Play.',
      ]);
      expect(find.textContaining('NEW'), findsNWidgets(9));
      _not(['Resubscribe', 'Resume', 'Paused', 'Renew']);
    });

    testWidgets('numbers follow the plan values (routes Plus 7)', (t) async {
      await _pump(t, Fx.free('Taxi'), plusFeatures: {...taxiPlusFeatures, 'Routes': 7});
      _has(['Free plan: 1 route. Plus allows up to 7.']);
      expect(find.text('7'), findsWidgets);
    });

    testWidgets('trial button only with 1 month and trialAvailable', (t) async {
      await _pump(t, Fx.free('Taxi'));
      expect(find.text('Try free for 7 days'), findsOneWidget);
      await t.tap(find.text('3 months').first);
      await settlePhone(t);
      expect(find.text('Try free for 7 days'), findsNothing);
      _has(['Plus · 3 months', '₹400 today']);
    });

    testWidgets('no trial button when trialAvailable is false', (t) async {
      await _pump(t, Fx.free('Taxi', trial: false));
      expect(find.text('Try free for 7 days'), findsNothing);
    });
  });

  group('o_pl_2 stay Free', () {
    testWidgets('every string, 14 rows, prices', (t) async {
      await _pump(t, Fx.free('Stay'));
      _has([
        'Stay plan', '2 photos', '2 room types', '1 job post', 'Not first in trip plans', 'Photos', '2 of 2', 'Room types 2 of 2',
        'First in trip plans', 'Featured near you', 'Job posts', 'Enquiries and offers', 'Bookings you add', 'Blocked day ranges',
        'Money notes on each booking', 'Special prices', '₹400', '₹367', 'Save 8%', '₹317', 'Save 21%', 'Billed ₹1,100 every 3 months',
        'Billed ₹3,800 a year', 'Then ₹400/month. Cancel anytime in Google Play.',
      ]);
      expect(find.textContaining('NEW'), findsNWidgets(11));
    });
  });

  group('o_pl_3 / o_pl_15 A trial', () {
    testWidgets('taxi trial', (t) async {
      await _pump(t, Fx.trial('Taxi'));
      _has(['Trial', 'Active', 'Plus', 'Billed by Google Play', 'Up to 5 routes', 'Your turn 2x as often', 'Featured in taxi lists', '5 of 5',
        'Trial ends on 28 Nov 2026', 'Then it renews. Cancel anytime in Google Play.', 'Manage in Google Play',
        'Use the Google account you subscribed with.', 'Change duration', 'Takes effect at your next renewal', 'Your current cycle', 'Current plan']);
      expect(find.text('Try free for 7 days'), findsNothing);
      expect(find.text('What you get'), findsNothing);
    });

    testWidgets('stay trial wording', (t) async {
      await _pump(t, Fx.trial('Stay'));
      _has(['Free until 28 Nov', 'First in trip plans', '8 photos, 6 room types, 4 jobs', '8 photos and 6 room types are open now.']);
    });
  });

  group('o_pl_4 stay Plus active', () {
    testWidgets('renews, no week block without counters', (t) async {
      await _pump(t, Fx.plus('Stay'));
      _has(['Active', 'Billed by Google Play', 'First in trip plans', 'Featured near you', '8 photos, 6 room types', '4 job posts',
        'Renews on 21 Dec 2026', 'Manage in Google Play', 'Change duration', 'Current plan']);
      _not(['This week', '0 Times']);
    });
  });

  group('o_pl_5 / o_pl_15 B cancelled', () {
    testWidgets('taxi: one button, no cycles, no bar', (t) async {
      await _pump(t, Fx.cancelled('Taxi'));
      _has(['Plus till 21 Dec 2026', 'Auto-renew is off.', 'After that, you keep 1 route.', 'Manage in Google Play']);
      expect(find.byType(PlanCycleOption), findsNothing);
      expect(_bar, findsNothing);
      _not(['Change duration', 'Subscribe again', 'Fix']);
    });

    testWidgets('loss line follows the free values (free routes 2)', (t) async {
      final c = installPlans(Fx.cancelled('Taxi'));
      c.catalog.value = PlanCatalogModel({'Taxi': [PlanModelX.freeWith('Taxi', {...taxiFreeFeatures, 'Routes': 2}), plusPlan('Taxi')]});
      await pumpPhone(t, const PlansBillingScreen(), size: const Size(392, 2000));
      await settlePhone(t);
      _has(['After that, you keep 2 routes.']);
    });

    testWidgets('stay wording', (t) async {
      await _pump(t, Fx.cancelled('Stay'));
      _has(['Auto-renew is off', 'After that, you keep 2 photos and 2 room types.']);
    });

    testWidgets('Manage opens Google Play', (t) async {
      await _pump(t, Fx.cancelled('Taxi'));
      await t.tap(find.text('Manage in Google Play'));
      await t.pump();
      expect(_fake.manageCalls, 1);
    });
  });

  group('o_pl_6 grace', () {
    testWidgets('stay grace: Fix, hero Active, bar disabled', (t) async {
      await _pump(t, Fx.grace('Stay'));
      _has(['Payment issue', 'Update your payment method to keep your plan.', 'Plus keeps working for now.', 'Fix', 'Active', 'Change duration']);
      await t.tap(find.text('Fix'));
      await t.pump();
      expect(_fake.manageCalls, 1);
    });

    testWidgets('taxi grace uses the taxi hero', (t) async {
      await _pump(t, Fx.grace('Taxi'));
      _has(['Up to 5 routes', 'Payment issue']);
    });
  });

  group('o_pl_7 / o_pl_15 C on hold', () {
    testWidgets('taxi on hold: free values, Fix, disabled buy with amber line, no trial', (t) async {
      await _pump(t, Fx.onHold('Taxi'));
      _has(['Free', 'No end date', '1 route', 'Subscription', 'Payment on hold', 'Fix the payment in Google Play to continue.',
        'Until then, you keep 1 route.', 'Fix', 'Fix the payment in Google Play first.', 'Continue with Plus']);
      expect(find.text('Try free for 7 days'), findsNothing);
      _not(['Paused', 'Resume']);
    });

    testWidgets('stay on hold wording', (t) async {
      await _pump(t, Fx.onHold('Stay'));
      _has(['Payment on hold', '2 photos, 2 room types, 1 job', 'Listed by distance', 'Until then, you keep 2 photos and 2 room types.']);
    });

    testWidgets('carried-over days read Plus till the date with Fix', (t) async {
      await _pump(t, Fx.onHold('Taxi', carry: 5));
      _has(['Plus till 5 Dec 2026', 'Fix']);
    });
  });

  group('o_pl_8 / o_pl_15 D ended', () {
    testWidgets('taxi ended: note, meter, Subscribe again, Choose your route', (t) async {
      await _pump(t, Fx.ended('Taxi'));
      _has(['Your first route stays. Extra routes are hidden, not deleted.', 'Subscription ended', 'Ended on 21 Dec 2026',
        'Extra routes are hidden. Nothing is deleted.', 'Subscribe again', 'Choose your route']);
      expect(find.text('Try free for 7 days'), findsNothing);
      expect(find.text('Subscribe again'), findsNWidgets(2));
    });

    testWidgets('stay ended wording', (t) async {
      await _pump(t, Fx.ended('Stay'));
      _has(['Cover and next photo stay. Extras are hidden, not deleted.', 'Up to 6 photos and 4 room types are hidden. Nothing is deleted.', 'Choose what stays']);
    });

    testWidgets('nothing hidden: no Choose button', (t) async {
      await _pump(t, Fx.ended('Taxi', hidden: false));
      expect(find.text('Choose your route'), findsNothing);
    });
  });

  group('o_pl_9 payment OFF', () {
    testWidgets('taxi: no bar, cycles, table, gate keys', (t) async {
      await _pump(t, Fx.off('Taxi'));
      _has(['Free', 'Free for now', 'Up to 5 routes ring', 'Requests, bookings, rating', 'Paid plans are coming',
        'Featured in taxi lists and your turn 2x as often. Not open yet.', 'History']);
      expect(find.byType(PlanCycleOption), findsNothing);
      expect(_bar, findsNothing);
      expect(find.byWidgetPredicate((w) => w.key is GateKey), findsNothing);
      _not(['See Plus', 'What you get', 'Have a coupon?', 'Restore purchases', 'of 5']);
    });

    testWidgets('stay line', (t) async {
      await _pump(t, Fx.off('Stay'));
      _has(['Plus will put your stay first in trip plans. Not open yet.']);
    });
  });

  group('size matrix', () {
    for (final (name, me) in [('free taxi', Fx.free('Taxi')), ('free stay', Fx.free('Stay')), ('ended taxi', Fx.ended('Taxi')), ('trial stay', Fx.trial('Stay')), ('off taxi', Fx.off('Taxi'))]) {
      testOwnerSizes(
        'plans page $name',
        () => const PlansBillingScreen(),
        setUpEach: () => installPlans(me),
        arrange: (t) async {
          await settlePhone(t);
          final s = find.byType(Scrollable).first;
          await t.drag(s, const Offset(0, -6000));
          await settlePhone(t);
        },
      );
    }
  });
}

FakePlans get _fake => Get.find<PlanController>() as FakePlans;

abstract final class PlanModelX {
  static PlanModel freeWith(String key, Map<String, int> features) => PlanModel(
        id: '${key}_free',
        featureKey: key,
        code: 'FREE',
        name: 'Free',
        tagline: null,
        isDefault: true,
        trialDays: 0,
        features: features,
        prices: const [],
      );
}
