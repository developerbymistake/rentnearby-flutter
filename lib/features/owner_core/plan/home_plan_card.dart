import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../config/app_routes.dart';
import '../../../controllers/plan_controller.dart';
import '../../../design/design.dart';
import '../../../design/extra/ext_plans.dart';
import '../../../widgets/plan_words.dart';
import '../home/owner_home_models.dart';
import 'gate_keys.dart';
import 'plan_card_state.dart';
import 'plan_gate.dart';

/// The one plan card under Upcoming on both owner Homes (o_pl_16). Words come from the role's [PlanRoleCopy].
class HomePlanCard extends StatelessWidget {
  const HomePlanCard({super.key, required this.card, required this.copy, this.city, this.values = const PlanValues()});

  final OwnerPlanCard? card;
  final PlanRoleCopy copy;
  final String? city;
  final PlanValues values;

  static void onAction(PlanHomeAction a) {
    switch (resolve(a)) {
      case PlanHomeAction.tryFree:
        Get.toNamed(AppRoutes.plansBilling, arguments: const {'trial': true});
      case PlanHomeAction.seePlus:
        PlanGate.seePlus();
      case PlanHomeAction.manage:
      case PlanHomeAction.fix:
        if (Get.isRegistered<PlanController>()) Get.find<PlanController>().openManageSubscription();
      case PlanHomeAction.subscribeAgain:
        Get.toNamed(AppRoutes.plansBilling);
      case PlanHomeAction.none:
        break;
    }
  }

  /// Try free only while the catalog really carries a trial; otherwise the normal Plus action.
  static PlanHomeAction resolve(PlanHomeAction a) =>
      a == PlanHomeAction.tryFree && PlanGate.trialDays() == null ? PlanHomeAction.seePlus : a;

  static String? label(PlanHomeAction a) => switch (resolve(a)) {
        PlanHomeAction.tryFree => PlanWords.tryFree(PlanGate.trialDays()!),
        PlanHomeAction.seePlus => PlanWords.seePlus,
        PlanHomeAction.manage => PlanWords.manageInPlay,
        PlanHomeAction.fix => PlanWords.fix,
        PlanHomeAction.subscribeAgain => PlanWords.subscribeAgain,
        PlanHomeAction.none => null,
      };

  ListingTone _tone(PlanHomeLook look) => switch (look) {
        PlanHomeLook.plus => copy.homeTone,
        PlanHomeLook.warn => PlanLook.warmTone,
        PlanHomeLook.ended => PlanLook.endedTone,
        PlanHomeLook.off => PlanLook.offTone,
      };

  @override
  Widget build(BuildContext context) {
    final v = copy.homeCard(card, city: city, v: values);
    final action = resolve(v.action);
    final upsell = action == PlanHomeAction.seePlus || action == PlanHomeAction.tryFree;
    return PlanHomeCard3D(
      key: ValueKey('home_plan_card_${v.state.name}'),
      tone: _tone(v.look),
      art: v.art,
      title: v.title,
      pill: v.pill,
      line: v.line,
      actionLabel: label(action),
      onAction: () => onAction(action),
      actionKey: upsell ? GateKeys.seePlus : null,
    );
  }
}
