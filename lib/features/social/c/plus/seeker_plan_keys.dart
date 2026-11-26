import 'package:get/get.dart';

import '../../../../controllers/plan_controller.dart';
import '../../../../models/plan_model.dart';
import '../../../../widgets/plan_subscription_card.dart';

abstract final class SeekerPlanKeys {
  static const String featureKey = 'Seeker';
  static const String activeTrips = 'SeekerActiveTrips';
  static const String publicTrips = 'SeekerPublicTrips';
  static const String joinRequests = 'SeekerJoinRequestsPerMonth';
  static const String newChats = 'SeekerNewChatsPerMonth';
  static const String genderOnly = 'SeekerGenderOnlyTrips';
  static const String nearMe = 'SeekerNearMe';

  static PlanController? get plans => Get.isRegistered<PlanController>() ? Get.find<PlanController>() : null;

  static List<PlanModel> seekerPlans(PlanCatalogModel? catalog) => catalog?.plansOf(featureKey) ?? const [];

  static String? statusLine() {
    final me = plans?.myPlan.value;
    if (me == null || me.featureKey != featureKey) return null;
    return PlanStateCopy.status(me);
  }

  static PlanModel? plusPlan(PlanCatalogModel? catalog) {
    for (final p in seekerPlans(catalog)) {
      if (!p.isDefault && p.prices.isNotEmpty) return p;
    }
    return null;
  }
}
