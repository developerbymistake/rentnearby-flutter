import 'package:get/get.dart';

class StayOwnerHomeController extends GetxController {
  final centreBadge = 0.obs;

  static StayOwnerHomeController? get maybe =>
      Get.isRegistered<StayOwnerHomeController>() ? Get.find<StayOwnerHomeController>() : null;
}
