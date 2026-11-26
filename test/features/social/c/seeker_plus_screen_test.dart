import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/social/c/plus/seeker_plus_controller.dart';
import 'package:bakhli/features/social/c/plus/seeker_plus_screen.dart';
import 'package:bakhli/features/social/c/social_strings_c.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'plus_fakes.dart';
import 'social_c_test_kit.dart';

void main() {
  useBuddyRenderScale();
  tearDown(Get.reset);

  FakePlanController setUpPlans({bool paid = false, bool plus = false}) {
    final plans = Get.put<PlanController>(FakePlanController(paid: paid));
    Get.put<SocialMeController>(FakeSocialMeController(plus ? plusLimits() : freeLimits()));
    return plans as FakePlanController;
  }

  double sizeOf(WidgetTester t, Key key) => t.widget<Text>(find.byKey(key)).style!.fontSize!;

  for (final w in socialWidths) {
    for (final s in socialScales) {
      testWidgets('12 months is preselected and the charged amount is the biggest number (${w.toInt()} x$s)', (t) async {
        setUpPlans();
        await pumpSocial(t, const SeekerPlusScreen(from: 'chat'), width: w, scale: s);
        expect(find.text(SocialStringsC.priceYear('₹1,800')), findsOneWidget);
        expect(find.text(SocialStringsC.priceFor3('₹500')), findsOneWidget);
        expect(find.text(SocialStringsC.priceMonth('₹200')), findsOneWidget);
        expect(find.text(SocialStringsC.bestValue), findsOneWidget);
        expect(find.text(SocialStringsC.footerToday('₹1,800')), findsOneWidget);
        expect(sizeOf(t, const ValueKey('plus_price_12')), greaterThan(sizeOf(t, const ValueKey('plus_per_month_12'))));
        expect(sizeOf(t, const ValueKey('plus_price_12')), greaterThan(sizeOf(t, const ValueKey('plus_footer_price'))));
        expect(find.text(SocialStringsC.perMonthAbout('₹150')), findsOneWidget);
        expect(find.text(SocialStringsC.autoRenew), findsOneWidget);
        expect(find.textContaining('trial', findRichText: true), findsNothing);
        expect(find.textContaining('Trial', findRichText: true), findsNothing);
        expect(t.takeException(), isNull);
        await disposeSocial(t);
      });
    }
  }

  testWidgets('the Plus page uses the large page header with the money bag', (t) async {
    setUpPlans();
    await pumpSocial(t, const SeekerPlusScreen());
    expect(find.byKey(const ValueKey('plus_page_header')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('plus_page_header')), matching: find.text(SocialStringsC.plusTitle)), findsOneWidget);
    expect(t.takeException(), isNull);
    await disposeSocial(t);
  });

  testWidgets('what you get uses the plan numbers, not typed ones', (t) async {
    setUpPlans();
    await pumpSocial(t, const SeekerPlusScreen());
    expect(find.text(SocialStringsC.chatPeople(10)), findsOneWidget);
    expect(find.text('Chat with 10 new people a month'), findsOneWidget);
    expect(find.text(SocialStringsC.chatPeopleSub(3)), findsOneWidget);
    expect(find.text(SocialStringsC.publicTrips(3)), findsOneWidget);
    expect(find.text(SocialStringsC.activeTrips(10)), findsOneWidget);
    expect(find.text(SocialStringsC.joinRequests(5)), findsOneWidget);
    expect(find.text(SocialStringsC.genderOnly), findsOneWidget);
    expect(find.text('Women-only trips'), findsOneWidget);
    expect(find.text('Men-only and Anyone are free'), findsOneWidget);
    expect(find.textContaining('or men-only'), findsNothing);
    expect(find.text(SocialStringsC.nearMe), findsOneWidget);
    await disposeSocial(t);
  });

  testWidgets('picking 3 months and Subscribe buys that cycle through the plan code', (t) async {
    final plans = setUpPlans();
    await pumpSocial(t, const SeekerPlusScreen());
    await t.tap(find.byKey(const ValueKey('plus_cycle_3')));
    await t.pump();
    expect(find.text(SocialStringsC.footerToday('₹500')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('plus_subscribe')));
    await t.pump();
    expect(plans.bought, [('b1000000-0000-0000-0000-000000000502', 3)]);
    await disposeSocial(t);
  });

  testWidgets('plan cards and their ring use uniform corners', (t) async {
    setUpPlans();
    await pumpSocial(t, const SeekerPlusScreen());
    for (final m in [12, 3, 1]) {
      final ring = t.widget<Container>(find.byKey(ValueKey('plus_ring_$m')));
      final ringR = (ring.decoration! as BoxDecoration).borderRadius! as BorderRadius;
      expect(ringR, DS.br(const BorderRadius.all(Radius.circular(CardRadius.uniformValue + 5))));
      final card = t.widget<Container>(find.descendant(of: find.byKey(ValueKey('plus_ring_$m')), matching: find.byType(Container)).first);
      expect((card.decoration! as BoxDecoration).borderRadius, DS.br(CardRadius.card));
    }
    await disposeSocial(t);
  });

  testWidgets('a Plus member sees Manage in Google Play and no plan cards', (t) async {
    setUpPlans(paid: true, plus: true);
    await pumpSocial(t, const SeekerPlusScreen());
    expect(find.byKey(const ValueKey('plus_subscribed')), findsOneWidget);
    expect(find.byKey(const ValueKey('plus_manage')), findsOneWidget);
    expect(find.byKey(const ValueKey('plus_cycle_12')), findsNothing);
    expect(find.byKey(const ValueKey('plus_subscribe')), findsNothing);
    await disposeSocial(t);
  });

  test('cycles are ordered 12, 3, 1', () {
    final c = SeekerPlusController(plans: FakePlanController());
    expect(c.cycles, [12, 3, 1]);
    expect(c.cycle(12)?.perMonth, '₹150');
    expect(c.cycle(1)?.perMonth, isNull);
  });
}
