import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/social/c/plus/seeker_plus_screen.dart';
import 'package:bakhli/features/social/c/social_strings_c.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/social/shared/social_models.dart';
import 'package:bakhli/models/my_plan_model.dart';
import 'package:bakhli/widgets/plan_words.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'plus_fakes.dart';
import 'social_c_test_kit.dart';

PlaySubInfo _play(String state, {bool autoRenew = true, bool owns = true}) => PlaySubInfo(
      state: state,
      autoRenewEnabled: autoRenew,
      expiryAt: DateTime(2026, 12, 26),
      trialEndsAt: null,
      productId: 'seeker_plus',
      basePlanId: 'cycle-12m',
      offerId: null,
      scheduledPlanName: null,
      scheduledAt: null,
      isTest: false,
      acknowledged: true,
      pausedAutoResumeAt: null,
      cancelReason: null,
      ownsActivePlan: owns,
    );

SocialLimits _free({int inactive = 0, int paused = 0}) => SocialLimits(
      isPlus: false,
      canUpgrade: true,
      activeTrips: const LimitUse(limit: 1, used: 1),
      publicTrips: const LimitUse(limit: 1, used: 0),
      joinRequests: const LimitUse(limit: 1, used: 0),
      newChats: const LimitUse(limit: 3, used: 0),
      genderOnlyTrips: false,
      nearMe: false,
      inactiveTrips: inactive,
      pausedPosts: paused,
    );

void main() {
  useBuddyRenderScale();
  tearDown(Get.reset);

  void setUp({required String state, required bool paid, required PlaySubInfo play, SocialLimits? limits}) {
    final plans = FakePlanController(paid: paid);
    plans.myPlan.value = MyPlanModel(
      paymentEnabled: true,
      featureKey: 'Seeker',
      isPaid: paid,
      isDefault: !paid,
      planName: paid ? 'Bakhli Plus' : 'Free',
      endsAt: DateTime(2026, 12, 26),
      play: play,
      state: state,
    );
    Get.put<PlanController>(plans);
    Get.put<SocialMeController>(FakeSocialMeController(limits ?? (paid ? plusLimits() : _free())));
  }

  bool subscribeEnabled(WidgetTester t) => t.widget<GradientPillButton>(find.byKey(const ValueKey('plus_subscribe'))).enabled;

  for (final w in socialWidths) {
    for (final s in socialScales) {
      testWidgets('active auto-renew shows Renews on and no plan cards (${w.toInt()} x$s)', (t) async {
        setUp(state: 'Plus', paid: true, play: _play('SUBSCRIPTION_STATE_ACTIVE'));
        await pumpSocial(t, const SeekerPlusScreen(), width: w, scale: s);
        expect(find.byKey(const ValueKey('plus_lifecycle_card')), findsOneWidget);
        expect(find.textContaining('Renews on'), findsWidgets);
        expect(find.byKey(const ValueKey('plus_cycle_12')), findsNothing);
        expect(t.takeException(), isNull);
        await disposeSocial(t);
      });
    }
  }

  testWidgets('cancelled but still active shows Plus till and Resubscribe', (t) async {
    setUp(state: 'Cancelled', paid: true, play: _play('SUBSCRIPTION_STATE_CANCELED', autoRenew: false));
    await pumpSocial(t, const SeekerPlusScreen());
    expect(find.textContaining('Plus till'), findsOneWidget);
    expect(find.text(PlanWords.resubscribe), findsOneWidget);
    await disposeSocial(t);
  });

  testWidgets('grace shows Payment issue and Fix while Plus keeps working', (t) async {
    setUp(state: 'Grace', paid: true, play: _play('SUBSCRIPTION_STATE_IN_GRACE_PERIOD'));
    await pumpSocial(t, const SeekerPlusScreen());
    expect(find.text(PlanWords.paymentIssue), findsOneWidget);
    expect(find.text(PlanWords.fix), findsOneWidget);
    expect(find.byKey(const ValueKey('plus_subscribed')), findsOneWidget);
    await disposeSocial(t);
  });

  testWidgets('on hold shows the strip on the free limits and blocks a new purchase', (t) async {
    setUp(state: 'OnHold', paid: false, play: _play('SUBSCRIPTION_STATE_ON_HOLD', owns: false));
    await pumpSocial(t, const SeekerPlusScreen());
    expect(find.text(PlanWords.paymentOnHold), findsOneWidget);
    expect(subscribeEnabled(t), isFalse);
    await disposeSocial(t);
  });

  testWidgets('ended shows Subscription ended, Subscribe again and the plan cards', (t) async {
    setUp(state: 'Ended', paid: false, play: _play('SUBSCRIPTION_STATE_EXPIRED', autoRenew: false, owns: false));
    await pumpSocial(t, const SeekerPlusScreen());
    expect(find.text(PlanWords.subscriptionEnded), findsOneWidget);
    expect(find.text(PlanWords.subscribeAgain), findsOneWidget);
    expect(find.byKey(const ValueKey('plus_cycle_12')), findsOneWidget);
    expect(subscribeEnabled(t), isTrue);
    await disposeSocial(t);
  });

  testWidgets('after expiry the paused trips line tells what Plus brings back', (t) async {
    setUp(state: 'Ended', paid: false, play: _play('SUBSCRIPTION_STATE_EXPIRED', autoRenew: false, owns: false), limits: _free(inactive: 2, paused: 1));
    await pumpSocial(t, const SeekerPlusScreen());
    expect(find.text(SocialStringsC.pausedLine(3)), findsOneWidget);
    await disposeSocial(t);
  });

  testWidgets('a Plus member never sees the paused line', (t) async {
    setUp(state: 'Plus', paid: true, play: _play('SUBSCRIPTION_STATE_ACTIVE'));
    await pumpSocial(t, const SeekerPlusScreen());
    expect(find.byKey(const ValueKey('plus_paused_line')), findsNothing);
    await disposeSocial(t);
  });

  test('paused line words', () {
    expect(SocialStringsC.pausedLine(1), '1 trip is paused. Buy Plus to restore it.');
    expect(SocialStringsC.inactiveTrip(1), 'Inactive: the Free plan allows 1 active trip');
  });
}
