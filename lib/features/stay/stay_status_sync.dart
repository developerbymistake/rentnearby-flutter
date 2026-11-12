import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import 'guest/stay_landing_controller.dart';
import 'guest/v2/stay_landing_controller_v2.dart';

abstract final class StayStatusSync {
  static void onReviewResult() {
    Get.find<AuthController>().refreshProfile();
    if (Get.isRegistered<StayLandingControllerV2>(tag: StayLandingControllerV2.tag)) Get.find<StayLandingControllerV2>(tag: StayLandingControllerV2.tag).stayPostedTrigger.value++;
    if (Get.isRegistered<StayLandingController>(tag: StayLandingController.tag)) {
      Get.find<StayLandingController>(tag: StayLandingController.tag).stayPostedTrigger.value++;
    }
  }
}
