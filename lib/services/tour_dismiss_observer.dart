import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../controllers/tour_controller.dart';

/// Any route pushed on the root Navigator (a notification tap, a deep link,
/// anything) while a tour is showing invalidates that tour's spotlight
/// target — force-dismiss it. Guarded by Get.isRegistered since didPush also
/// fires for /splash and /login, pushed before MainScreen ever registers
/// TourController.
class TourDismissObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!Get.isRegistered<TourController>()) return;
    try {
      Get.find<TourController>().forceDismissForNavigation();
    } catch (_) {}
  }
}
