import 'package:get/get.dart';

import 'chat/open_room_tracker.dart';
import 'chat/rooms_controller.dart';

abstract final class SocialBindingsC {
  static void ensure() {
    if (!Get.isRegistered<RoomsController>()) Get.put(RoomsController(), permanent: true);
  }
}

abstract final class SocialSessionC {
  static void clear() {
    RoomsController.maybe?.clear();
    if (Get.isRegistered<RoomsController>()) Get.delete<RoomsController>(force: true);
    OpenRoomTracker.clear();
  }
}
