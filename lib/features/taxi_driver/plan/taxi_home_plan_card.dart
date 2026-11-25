import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../controllers/plan_controller.dart';
import '../../../models/plan_model.dart';
import '../../owner_core/home/owner_home_models.dart';
import '../../owner_core/plan/home_plan_card.dart';
import '../../owner_core/plan/plan_card_state.dart';
import '../home/taxi_driver_home_controller.dart';
import 'taxi_plan_copy.dart';

class TaxiHomePlanCard extends StatelessWidget {
  const TaxiHomePlanCard({super.key});

  @override
  Widget build(BuildContext context) {
    final home = TaxiDriverHomeController.maybe;
    final plans = Get.isRegistered<PlanController>() ? Get.find<PlanController>() : null;
    if (home == null && plans == null) return _card(null, null, const []);
    return Obx(() {
      final dto = home?.load.value.valueOrNull;
      final me = plans?.myPlan.value;
      final card = feedCardFresh(home?.loadedAt, dto != null, home?.planChangedAt.value)
          ? (dto?.planCard ?? (me == null ? null : PlanCardStates.fromPlan(me)))
          : (me == null ? dto?.planCard : PlanCardStates.fromPlan(me));
      return _card(card, dto?.listing.cityName, plans?.plans.toList() ?? const []);
    });
  }

  static bool feedCardFresh(DateTime? homeAt, bool hasFeed, DateTime? planChangedAt) {
    if (!hasFeed) return false;
    if (planChangedAt == null) return true;
    return homeAt != null && !homeAt.isBefore(planChangedAt);
  }

  static const _hidden = {PlanCardState.free, PlanCardState.unknown, PlanCardState.paymentOff};

  static bool showsOnHome(OwnerPlanCard? card) => !_hidden.contains(card?.state ?? PlanCardState.unknown);

  static Widget _card(OwnerPlanCard? card, String? city, List<PlanModel> catalog) => !showsOnHome(card)
      ? const SizedBox.shrink()
      : HomePlanCard(
        card: card,
        copy: const TaxiPlanCopy(),
        city: city,
        values: PlanValues.fromCatalog(catalog),
      );
}
