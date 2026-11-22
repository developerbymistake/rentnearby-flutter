import 'package:get/get.dart';

import '../trip/controllers/my_trips_controller.dart';
import 'seeker_feed_controller.dart';
import 'seeker_session.dart';

abstract final class SeekerHomeBindings {
  static void ensure() {
    SeekerSession.register();
    // A1 bindings
    if (!Get.isRegistered<SeekerFeedController>()) {
      final trips = MyTripsController.to;
      Get.put(SeekerFeedController()).attachTripsList(trips.active, offlineCopyAt: trips.offlineCopyAt);
    }
    // end A1
  }
}
