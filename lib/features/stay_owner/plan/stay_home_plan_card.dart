import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../controllers/plan_controller.dart';
import '../../../models/plan_model.dart';
import '../../owner_core/home/owner_home_models.dart';
import '../../owner_core/plan/home_plan_card.dart';
import '../../owner_core/plan/plan_card_state.dart';
import '../home/stay_owner_home_controller.dart';
import 'stay_plan_copy.dart';

class StayHomePlanCard extends StatelessWidget {
  const StayHomePlanCard({super.key});

  @override
  Widget build(BuildContext context) {
    final home = StayOwnerHomeController.maybe;
    final plans = Get.isRegistered<PlanController>() ? Get.find<PlanController>() : null;
    if (home == null && plans == null) return _card(null, null, const []);
    return Obx(() {
      final dto = home?.load.value.valueOrNull;
      final me = plans?.myPlan.value;
      final fresh = plans == null || (home?.planVersionAtLoad ?? 0) == plans.planVersion.value;
      final card = (fresh ? dto?.planCard : null) ?? (me == null ? null : PlanCardStates.fromPlan(me));
      return _card(card, dto?.listing.cityName, plans?.plans.toList() ?? const []);
    });
  }

  static Widget _card(OwnerPlanCard? card, String? city, List<PlanModel> catalog) => HomePlanCard(
        card: card,
        copy: const StayPlanCopy(),
        city: city,
        values: PlanValues.fromCatalog(catalog),
      );
}
