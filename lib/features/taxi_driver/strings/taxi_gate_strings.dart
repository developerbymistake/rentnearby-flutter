import 'package:get/get.dart';

import '../../../controllers/plan_controller.dart';
import '../../../design/design.dart';
import '../../../models/plan_model.dart';
import '../../owner_core/plan/plan_card_state.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/plan_keys.dart';
import '../../owner_core/strings/owner_shared_strings.dart';

abstract final class TaxiGateStrings {
  static String routesCount(int n) => n == 1 ? '1 route' : '$n routes';
  static String routeTitle(int free) => '${routesCount(free)} on Free';
  static String routeBody(int plus) => 'Get Plus to add up to $plus routes.';
  static String plusRowValue(int plus) => 'Up to $plus routes, more requests';
  static String freePlanTip(int free, int plus) => 'Free plan keeps ${routesCount(free)}. Get Plus to add up to $plus.';
  static String lineFree(int free, int plus) => 'Free plan: ${routesCount(free)}. Plus allows up to $plus routes.';
  static String moreRoutes(int n) => n == 1 ? '1 more route' : '$n more routes';
  static String addUpTo(int plus) => 'Add up to $plus routes with Plus.';
  static const now = 'Now';
  static String chipPlus(int plus) => '$plus routes';
  static const addAnother = 'Add another route';
  static String upTo(int n) => 'You can add up to ${routesCount(n)}.';

  static int get freeRoutes => PlanGate.limit(PlanKey.routes);
  static int get plusRoutes {
    final plans = PlanGate.debugPlan == null && Get.isRegistered<PlanController>() ? Get.find<PlanController>().plans.toList() : const <PlanModel>[];
    return PlanValues.fromCatalog(plans).plus(PlanKey.routes);
  }

  static GateSpec routeGate({int? free}) {
    free ??= freeRoutes;
    final plus = plusRoutes;
    return GateSpec(
      id: 'G1',
      title: routeTitle(free),
      body: routeBody(plus),
      taxi: true,
      art: ListingArt.crown,
      rows: [
        GateRow(label: OwnerSharedStrings.free, value: routesCount(free), sub: now),
        GateRow(label: OwnerSharedStrings.plus, value: plusRowValue(plus), sub: chipPlus(plus), highlight: true),
      ],
    );
  }

  static GateSpec fromRefusal(String key, int limit) => routeGate(free: limit);
}
