import 'package:get/get.dart';

class TaxiDriverHomeController extends GetxController {
  final centreBadge = 0.obs;

  static TaxiDriverHomeController? get maybe =>
      Get.isRegistered<TaxiDriverHomeController>() ? Get.find<TaxiDriverHomeController>() : null;
}
