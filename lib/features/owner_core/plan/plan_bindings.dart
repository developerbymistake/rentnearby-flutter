import 'package:get/get.dart';

import '../../../controllers/plan_controller.dart';
import '../../../repositories/plan_repository.dart';
import '../session/owner_plan_sync.dart';

// Permanent: the setup hubs hand over to MainScreen with offAllNamed, and a route-linked
// controller would be deleted with the setup route after MainScreen already found it.
// Logout deletes both explicitly (AuthController._cleanupSession).
abstract final class PlanBindings {
  static void ensure({bool fresh = false}) {
    if (!Get.isRegistered<PlanRepository>()) Get.put(PlanRepository(), permanent: true);
    if (Get.isRegistered<PlanController>()) {
      final c = Get.find<PlanController>();
      if (fresh) {
        c.clear();
        c.refreshPlan(force: true);
      }
      OwnerPlanSync.bind(c.planVersion);
      return;
    }
    final c = Get.put(PlanController(), permanent: true);
    OwnerPlanSync.bind(c.planVersion);
  }

  static void dispose() {
    OwnerPlanSync.reset();
    if (Get.isRegistered<PlanController>()) Get.delete<PlanController>(force: true);
    if (Get.isRegistered<PlanRepository>()) Get.delete<PlanRepository>(force: true);
  }
}
