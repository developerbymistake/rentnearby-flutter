import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../controllers/plan_controller.dart';
import '../../../design/design.dart';
import '../../../models/my_plan_model.dart';
import 'plan_card_state.dart';

/// The Profile "Plans & Billing" sub line: "Free · 2 of 2 photos" / "Free · 1 of 1 route" (o_st_23, o_tx_22).
class ProfilePlanCard extends StatelessWidget {
  const ProfilePlanCard({super.key, required this.copy, this.style});

  final PlanRoleCopy copy;
  final TextStyle? style;

  static String lineFor(PlanRoleCopy copy, MyPlanModel me) => copy.profileLine(me);

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<PlanController>()) return const SizedBox.shrink();
    final plans = Get.find<PlanController>();
    return Obx(() => Text(
          lineFor(copy, plans.myPlan.value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style ?? Ink3D.text(13, FontWeight.w400, Ink3D.grey, letterSpacing: 0),
        ));
  }
}
