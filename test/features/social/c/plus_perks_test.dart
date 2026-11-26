import 'package:bakhli/features/social/c/plus/seeker_plus_controller.dart';
import 'package:bakhli/features/social/c/social_strings_c.dart';
import 'package:bakhli/features/social/shared/social_me_controller.dart';
import 'package:bakhli/features/trip/widgets/hub/hub_art.dart';
import 'package:bakhli/models/plan_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'plus_fakes.dart';

void main() {
  tearDown(Get.reset);

  test('Free numbers on the perks come from the Free plan in the catalog', () {
    Get.put<SocialMeController>(FakeSocialMeController(plusLimits()));
    final c = SeekerPlusController(plans: FakePlanController(paid: true));
    final perks = c.perks();
    expect(perks.first.subtitle, SocialStringsC.chatPeopleSub(3));
  });

  test('a Plus user with no Free plan in the catalog sees no invented Free number', () {
    Get.put<SocialMeController>(FakeSocialMeController(plusLimits()));
    final plans = FakePlanController(paid: true)..catalog.value = PlanCatalogModel({'Seeker': [seekerPlus()]});
    final c = SeekerPlusController(plans: plans);
    expect(c.perks().where((p) => p.subtitle != null && p.title != SocialStringsC.genderOnly && p.title != SocialStringsC.nearMe), isEmpty);
  });

  test('the women-only or men-only perk uses the woman raising hand art', () {
    Get.put<SocialMeController>(FakeSocialMeController(freeLimits()));
    final c = SeekerPlusController(plans: FakePlanController());
    expect(c.perks().firstWhere((p) => p.title == SocialStringsC.genderOnly).art, HubArt.womanRaising);
  });

  test('a Free user with no Free plan in the catalog sees his own limits from the server', () {
    Get.put<SocialMeController>(FakeSocialMeController(freeLimits()));
    final plans = FakePlanController()..catalog.value = PlanCatalogModel({'Seeker': [seekerPlus()]});
    final c = SeekerPlusController(plans: plans);
    expect(c.perks().first.subtitle, SocialStringsC.chatPeopleSub(3));
  });
}
