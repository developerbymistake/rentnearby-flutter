import 'package:get/get.dart';

import 'models/post_draft.dart';
import 'rail/trips_rail_controller.dart';

abstract final class SocialBindingsB {
  static void ensure() {
    if (!Get.isRegistered<TripsRailController>()) Get.put(TripsRailController(), permanent: true);
  }
}

abstract final class SocialSessionB {
  static void clear() {
    TripsRailController.maybe?.clear();
    if (Get.isRegistered<TripsRailController>()) Get.delete<TripsRailController>(force: true);
    PostDraftStore.clear().ignore();
  }
}
