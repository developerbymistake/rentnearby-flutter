import 'package:get/get.dart';

import 'b/social_bindings_b.dart';
import 'c/social_bindings_c.dart';
import 'shared/social_me_controller.dart';

abstract final class SocialBindings {
  static void ensure({required bool traveller}) {
    if (!traveller) return;
    if (!Get.isRegistered<SocialMeController>()) Get.put(SocialMeController(), permanent: true);
    SocialBindingsB.ensure();
    SocialBindingsC.ensure();
  }
}
