import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import 'guest/stay_landing_controller.dart';

abstract final class StayStatusSync {
  static void onReviewResult() {
    Get.find<AuthController>().refreshProfile();
    if (Get.isRegistered<StayLandingController>(tag: StayLandingController.tag)) {
      Get.find<StayLandingController>(tag: StayLandingController.tag).stayPostedTrigger.value++;
    }
  }
}
