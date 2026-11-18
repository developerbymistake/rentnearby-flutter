import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import 'guest/taxi_list_controller.dart';
import 'guest/v2/taxi_list_controller_v2.dart';
import 'setup/taxi_setup_controller.dart';

abstract final class TaxiStatusSync {
  // The V1 list is only ever pushed (pushTag); its root tag stays covered in case a root list is built.
  static void refreshLists() {
    TaxiListController.refreshRegistered();
    if (Get.isRegistered<TaxiListControllerV2>(tag: TaxiListControllerV2.tag)) {
      Get.find<TaxiListControllerV2>(tag: TaxiListControllerV2.tag).refreshTrigger.value++;
    }
  }

  static void onTaxiTabTap() {
    if (Get.isRegistered<TaxiListControllerV2>(tag: TaxiListControllerV2.tag)) {
      Get.find<TaxiListControllerV2>(tag: TaxiListControllerV2.tag).refreshIfStale();
    }
  }

  static void onReviewResult() {
    Get.find<AuthController>().refreshProfile();
    refreshLists();
    if (Get.isRegistered<TaxiSetupController>()) {
      TaxiSetupController.ensure().load();
    }
  }
}
