import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import 'guest/taxi_list_controller.dart';
import 'setup/taxi_setup_controller.dart';

abstract final class TaxiStatusSync {
  static void onReviewResult() {
    Get.find<AuthController>().refreshProfile();
    if (Get.isRegistered<TaxiListController>(tag: TaxiListController.tag)) {
      Get.find<TaxiListController>(tag: TaxiListController.tag).refreshTrigger.value++;
    }
    if (Get.isRegistered<TaxiSetupController>()) {
      TaxiSetupController.ensure().load();
    }
  }
}
