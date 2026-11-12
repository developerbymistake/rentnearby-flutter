import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import 'guest/taxi_list_controller.dart';
import 'guest/v2/taxi_list_controller_v2.dart';
import 'setup/taxi_setup_controller.dart';

abstract final class TaxiStatusSync {
  static void onReviewResult() {
    Get.find<AuthController>().refreshProfile();
    if (Get.isRegistered<TaxiListController>(tag: TaxiListController.tag)) {
      Get.find<TaxiListController>(tag: TaxiListController.tag).refreshTrigger.value++;
    }
    if (Get.isRegistered<TaxiListControllerV2>(tag: TaxiListControllerV2.tag)) {
      Get.find<TaxiListControllerV2>(tag: TaxiListControllerV2.tag).refreshTrigger.value++;
    }
    if (Get.isRegistered<TaxiSetupController>()) {
      TaxiSetupController.ensure().load();
    }
  }
}
