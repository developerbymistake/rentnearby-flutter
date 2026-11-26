import 'package:get/get.dart';

import 'b/social_bindings_b.dart';
import 'c/social_bindings_c.dart';
import 'shared/social_live.dart';
import 'shared/social_me_controller.dart';

abstract final class SocialSessionHooks {
  static void onLogout() {
    SocialMeController.maybe?.clear();
    if (Get.isRegistered<SocialMeController>()) Get.delete<SocialMeController>(force: true);
    SocialLive.reset();
    SocialSessionB.clear();
    SocialSessionC.clear();
  }
}
