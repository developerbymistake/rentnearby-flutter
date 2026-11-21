import 'package:get/get.dart';

import '../trip/controllers/my_trips_controller.dart';
import 'seeker_feed_controller.dart';
import 'seeker_session.dart';

abstract final class SeekerHomeBindings {
  static void ensure() {
    SeekerSession.register();
    // A1 bindings
    if (!Get.isRegistered<SeekerFeedController>()) {
      Get.put(SeekerFeedController()).attachTripsList(MyTripsController.to.active);
    }
    // end A1
  }
}
