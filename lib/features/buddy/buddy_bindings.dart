import 'package:get/get.dart';

import 'buddies/controllers/buddy_summary_controller.dart';
import 'notices/controllers/notices_controller.dart';
import 'offline/offline_registration.dart';

abstract final class BuddyBindings {
  static void ensure({required bool traveller}) {
    if (!Get.isRegistered<NoticesController>()) Get.put(NoticesController());
    if (!traveller) return;
    if (!Get.isRegistered<BuddySummaryController>()) Get.put(BuddySummaryController());
    registerOfflineQueue();
  }
}
