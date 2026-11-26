import 'package:get/get.dart';

import '../../../config/app_routes.dart';

abstract final class SocialNavB {
  static int _feedsOpen = 0;
  static final RxInt posted = 0.obs;

  static void feedOpened() => _feedsOpen++;

  static void feedClosed() {
    if (_feedsOpen > 0) _feedsOpen--;
  }

  static bool get feedInStack => _feedsOpen > 0;

  static void backToTravelBuddies({bool posted = false}) {
    if (feedInStack) {
      Get.until((r) => r.settings.name == AppRoutes.travelBuddies || r.isFirst);
      if (posted) SocialNavB.posted.value++;
      return;
    }
    Get.offNamed(AppRoutes.travelBuddies, arguments: {if (posted) 'posted': true});
  }
}
