import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/plan_controller.dart';
import 'plan_card_state.dart';

// "Plan ended" push or inbox row: fresh /plans/me, then Choose when something is hidden, else Plans & Billing.
abstract final class PlanExpiredTap {
  static const String wire = 'plan_expired';
  static const String hub = 'PlanExpired';

  static bool handles(Object? type) => type == wire || type == hub;

  static Future<void> open() async {
    if (!Get.isRegistered<PlanController>()) return;
    final plans = Get.find<PlanController>();
    await plans.invalidate();
    final me = plans.myPlan.value;
    final copy = PlanCopies.of(me.featureKey);
    final auth = Get.isRegistered<AuthController>() ? Get.find<AuthController>() : null;
    if (copy != null && copy.canChoose(me)) {
      copy.openChooseFor(me);
      return;
    }
    if (auth == null || auth.canOpenRoute(AppRoutes.plansBilling)) Get.toNamed(AppRoutes.plansBilling);
  }
}
