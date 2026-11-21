import 'package:bakhli/config/shell_kind.dart';
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/controllers/tab_config_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_plans.dart';
import 'package:bakhli/features/owner_core/plan/plan_card_state.dart';
import 'package:bakhli/features/stay_owner/plan/stay_plan_copy.dart';
import 'package:bakhli/features/taxi_driver/plan/taxi_plan_copy.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/screens/plans_billing_screen.dart';
import 'package:bakhli/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/owner_fakes.dart';
import '../../support/real_phone.dart';
import '../taxi_driver/core/taxi_fixtures.dart';
import 'plans_harness.dart';

class _Tabs extends TabConfigController {
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  bool isActive(String tabKey) {
    version.value;
    return true;
  }
}

class _Auth extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

Future<void> _plans(WidgetTester t, MyPlanModel me, {double w = 392}) async {
  installPlans(me);
  await pumpPhone(t, const PlansBillingScreen(), size: Size(w, 3400));
  await settlePhone(t);
  await settlePhone(t);
}

Future<void> _profile(WidgetTester t, MyPlanModel me, {required bool stay}) async {
  if (stay) {
    Get.reset();
    Get.put<TabConfigController>(_Tabs());
    final a = Get.put<AuthController>(_Auth());
    a.roleKey.value = 'STAY_OWNER';
    a.canListStays.value = true;
    a.shellKind.value = ShellKind.stayOwner;
  } else {
    TaxiHarness.setUp(const {}).auth.shellKind.value = ShellKind.taxiDriver;
  }
  Get.put(PlanController()).myPlan.value = me;
  PlanCopies.stay = const StayPlanCopy();
  PlanCopies.taxi = const TaxiPlanCopy();
  await pumpPhone(t, const ProfileScreen(), size: const Size(392, 2400));
  await settlePhone(t);
}

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await initTestStorage('plans_verify');
  });
  tearDown(() {
    resetPlans();
    PlanCopies.reset();
    Get.reset();
  });

  group('o_pl_1 / o_pl_2 coupon and restore chips', () {
    for (final w in [320.0, 392.0]) {
      testWidgets('both chips sit in one chip row under the cycle cards ($w)', (t) async {
        await _plans(t, Fx.free('Taxi'), w: w);
        final row = find.byType(PlanLinkChips);
        expect(row, findsOneWidget);
        expect(find.descendant(of: row, matching: find.text('Have a coupon?')), findsOneWidget);
        expect(find.descendant(of: row, matching: find.text('Restore purchases')), findsOneWidget);
        expect(t.getTopLeft(row).dy, greaterThan(t.getBottomLeft(find.text('12 months').first).dy));
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('coupon chip opens the coupon field and Restore stays', (t) async {
      await _plans(t, Fx.free('Stay'));
      await t.tap(find.text('Have a coupon?'));
      await settlePhone(t);
      expect(find.text('Have a coupon?'), findsNothing);
      expect(find.byType(PlanCouponRow3D), findsOneWidget);
      expect(find.text('Restore purchases'), findsOneWidget);
    });

    testWidgets('an active plan shows no chips', (t) async {
      await _plans(t, Fx.plus('Stay'));
      expect(find.text('Have a coupon?'), findsNothing);
      expect(find.text('Restore purchases'), findsNothing);
    });
  });

  testWidgets('o_pl_6 grace note carries the star, other notes the map', (t) async {
    await _plans(t, Fx.grace('Stay'));
    var card = t.widget<PlanSubscriptionCard3D>(find.byType(PlanSubscriptionCard3D));
    expect(card.notes.first, (ListingArt.star, 'Plus keeps working for now.'));
    resetPlans();
    await _plans(t, Fx.cancelled('Taxi'));
    card = t.widget<PlanSubscriptionCard3D>(find.byType(PlanSubscriptionCard3D));
    expect(card.notes.first, (ListingArt.worldMap, 'After that, you keep 1 route.'));
  });

  group('Profile plan line (o_st_23, o_tx_22)', () {
    testWidgets('stay Free prints the photo count', (t) async {
      await _profile(t, Fx.free('Stay'), stay: true);
      expect(find.text('Free · 2 of 2 photos'), findsOneWidget);
    });

    testWidgets('taxi Free prints the route count', (t) async {
      await _profile(t, Fx.free('Taxi'), stay: false);
      expect(find.text('Free · 1 of 1 route'), findsOneWidget);
    });

    testWidgets('no usage from the server keeps the plan name', (t) async {
      await _profile(t, const MyPlanModel(paymentEnabled: true, featureKey: 'Taxi'), stay: false);
      expect(find.text('Free plan'), findsOneWidget);
      expect(find.textContaining(' route'), findsNothing);
    });

    testWidgets('payment OFF prints no limit number', (t) async {
      await _profile(t, Fx.off('Stay'), stay: true);
      expect(find.text('Free plan'), findsOneWidget);
      expect(find.textContaining('photos'), findsNothing);
    });
  });
}
