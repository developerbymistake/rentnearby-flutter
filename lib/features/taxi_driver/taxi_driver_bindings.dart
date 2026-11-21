import 'package:get/get.dart';

import 'home/taxi_driver_home_controller.dart';
import 'taxi_driver_session.dart';

abstract final class TaxiDriverBindings {
  static void ensure() {
    TaxiDriverSession.register();
    if (!Get.isRegistered<TaxiDriverHomeController>()) Get.put(TaxiDriverHomeController());
    // A5 bindings
    // end A5
    // A6 bindings
    // end A6
    // A7 bindings
    // end A7
    // A8 bindings
    // end A8
  }
}
