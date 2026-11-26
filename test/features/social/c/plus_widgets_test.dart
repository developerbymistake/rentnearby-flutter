import 'package:bakhli/controllers/plan_controller.dart';
import 'package:bakhli/features/social/c/social_strings_c.dart';
import 'package:bakhli/features/social/shared/social_error_types.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/social/shared/widgets/plus_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../../support/buddy_render.dart';
import 'plus_fakes.dart';
import 'social_c_test_kit.dart';

void main() {
  useBuddyRenderScale();
  tearDown(Get.reset);

  test('limit sheet handles the five cap types only', () {
    for (final t in [
      SocialErrorTypes.publicTripLimit,
      SocialErrorTypes.joinRequestLimit,
      SocialErrorTypes.newChatLimit,
      SocialErrorTypes.plusRequired,
      SocialErrorTypes.tripLimitReached,
    ]) {
      expect(PlusSheets.handles(t), isTrue, reason: t);
    }
    expect(PlusSheets.handles(SocialErrorTypes.awaitingReply), isFalse);
    expect(PlusSheets.handles(null), isFalse);
  });

  test('limit lines read the numbers from the server data first', () {
    final l = freeLimits();
    expect(PlusSheets.lineFor(SocialErrorTypes.newChatLimit, l, const {'limit': 3}), SocialStringsC.chatLimitLine(3));
    expect(PlusSheets.lineFor(SocialErrorTypes.joinRequestLimit, l, const {}), SocialStringsC.joinLimitLine(1));
    expect(PlusSheets.lineFor(SocialErrorTypes.plusRequired, l, const {}), SocialStringsC.plusFeatureLine);
  });

  Widget host(Widget child) => Scaffold(body: SingleChildScrollView(child: child));

  for (final w in socialWidths) {
    for (final s in socialScales) {
      testWidgets('banner shows for a free seeker who can upgrade, with Plus numbers (${w.toInt()} x$s)', (t) async {
        Get.put<PlanController>(FakePlanController());
        Get.put<SocialMeController>(FakeSocialMeController(freeLimits()));
        await pumpSocial(t, host(const PlusBanner()), width: w, scale: s);
        expect(find.byKey(const ValueKey('plus_banner')), findsOneWidget);
        expect(find.text(SocialStringsC.bannerTitle), findsOneWidget);
        expect(find.text(SocialStringsC.bannerChats(15)), findsOneWidget);
        expect(find.text(SocialStringsC.joinRequests(5)), findsOneWidget);
        expect(t.takeException(), isNull);
        await disposeSocial(t);
      });
    }
  }

  testWidgets('banner hides for Plus members and when upgrade is off', (t) async {
    Get.put<PlanController>(FakePlanController());
    Get.put<SocialMeController>(FakeSocialMeController(plusLimits()));
    await pumpSocial(t, host(const PlusBanner()));
    expect(find.byKey(const ValueKey('plus_banner')), findsNothing);
    await disposeSocial(t);
    Get.reset();
    Get.put<PlanController>(FakePlanController());
    Get.put<SocialMeController>(FakeSocialMeController(freeLimits(canUpgrade: false)));
    await pumpSocial(t, host(const PlusBanner()));
    expect(find.byKey(const ValueKey('plus_banner')), findsNothing);
    await disposeSocial(t);
  });

  testWidgets('lock line has See Plus', (t) async {
    Get.put<SocialMeController>(FakeSocialMeController(freeLimits()));
    await pumpSocial(t, host(const PlusLockLine(text: 'Near me is a Plus filter', from: 'filter')));
    expect(find.text('Near me is a Plus filter'), findsOneWidget);
    expect(find.byKey(const ValueKey('plus_lock_see_plus')), findsOneWidget);
    await disposeSocial(t);
  });

  testWidgets('limit sheet offers See Plus and Not now', (t) async {
    Get.put<SocialMeController>(FakeSocialMeController(freeLimits()));
    await pumpSocial(t, Builder(builder: (c) => Scaffold(body: Center(child: TextButton(onPressed: () => PlusSheets.limitReached(c, errorType: SocialErrorTypes.newChatLimit, data: const {'limit': 3}), child: const Text('open'))))));
    await t.tap(find.text('open'));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('plus_limit_sheet')), findsOneWidget);
    expect(find.text(SocialStringsC.limitReachedTitle), findsOneWidget);
    expect(find.text(SocialStringsC.seePlus), findsOneWidget);
    expect(find.text(SocialStringsC.notNow), findsOneWidget);
    await t.tap(find.text(SocialStringsC.notNow));
    await t.pump(const Duration(milliseconds: 500));
    await disposeSocial(t);
  });
}
