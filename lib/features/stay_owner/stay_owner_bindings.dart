import 'package:get/get.dart';

import 'home/stay_owner_home_controller.dart';
import 'stay_owner_session.dart';

abstract final class StayOwnerBindings {
  static void ensure() {
    StayOwnerSession.register();
    if (!Get.isRegistered<StayOwnerHomeController>()) Get.put(StayOwnerHomeController());
    // A2 bindings
    // end A2
    // A3 bindings
    // end A3
    // A4 bindings
    // end A4
    // A8 bindings
    // end A8
  }
}
