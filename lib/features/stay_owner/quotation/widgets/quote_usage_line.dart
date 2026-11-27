import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../controllers/plan_controller.dart';
import '../../../../design/design.dart';
import '../../../../models/my_plan_model.dart';
import '../../../owner_core/plan/plan_card_state.dart';
import '../../../owner_core/plan/plan_gate.dart';
import '../../../owner_core/strings/owner_shared_strings.dart';
import '../../strings/stay_quote_strings.dart';
import '../../widgets/stay_widgets.dart';
import '../controllers/quote_hub_controller.dart';
import '../data/quote_models.dart';
import '../model/quote_usage_view.dart';
import 'quote_line_card.dart';

abstract final class QuoteUsageSource {
  static MyPlanModel get plan => Get.isRegistered<PlanController>() ? Get.find<PlanController>().myPlan.value : const MyPlanModel();

  static DateTime? get _planLoaded => Get.isRegistered<PlanController>() ? Get.find<PlanController>().loadedAt : null;

  // The hub count wins when it is fresher (after a download); a hub saved before /plans/me last loaded with another limit is stale.
  static QuoteUsage? reconcile(QuoteUsage? hub, int planLimit, {DateTime? hubSavedAt, DateTime? planLoadedAt}) {
    if (hub == null || hub.limit == planLimit) return hub;
    final planNewer = planLoadedAt != null && (hubSavedAt == null || hubSavedAt.isBefore(planLoadedAt));
    return planNewer ? null : hub;
  }

  // Plan state from /plans/me; the count from the hub when it is fresher (after a download), else /plans/me.
  static QuoteUsageView view({QuoteUsage? hub, DateTime? hubSavedAt, DateTime? planLoadedAt, DateTime? now}) {
    final me = PlanGate.debugPlan ?? plan;
    final l = me.limits;
    final u = reconcile(hub, l.quotationsPerMonth, hubSavedAt: hubSavedAt ?? QuoteHubController.maybe?.savedAt, planLoadedAt: planLoadedAt ?? _planLoaded);
    return QuoteUsageView.of(
      state: PlanCardStates.ofPlan(me, now: now),
      used: u?.used ?? l.quotationsUsed,
      limit: u?.limit ?? l.quotationsPerMonth,
      resetsAt: u?.resetsAt ?? l.quotationsResetsAt,
      endsAt: me.play?.expiryAt ?? me.endsAt,
    );
  }
}

class QuoteUsageHero extends StatelessWidget {
  const QuoteUsageHero({super.key, required this.view, this.margin});

  final QuoteUsageView view;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final tone = view.seePlus ? StayLook.grey : ListingTone.forest;
    return Container(
      margin: margin ?? DS.insets(l: 18, t: 14, r: 18),
      padding: DS.all(16),
      decoration: BoxDecoration(gradient: tone.gradient, borderRadius: DS.br(CardRadius.hero), boxShadow: tone.glow()),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(view.top ?? StayQuoteStrings.thisMonth, style: QuoteText.small.copyWith(color: Colors.white)),
                Gap.v(2),
                Text(view.line1, style: TypeTokens.onGradientTitle),
                Gap.v(8),
                ClipRRect(
                  borderRadius: DS.circular(4),
                  child: LinearProgressIndicator(
                    value: view.fraction,
                    minHeight: DS.s(6),
                    backgroundColor: Colors.white.withValues(alpha: Alpha.v22),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                if (view.line2 != null) ...[
                  Gap.v(8),
                  Text(view.line2!, style: TypeTokens.onGradientBody),
                ],
                if (view.seePlus && PlanGate.canUpgrade) ...[
                  Gap.v(10),
                  StayWhitePill(label: OwnerSharedStrings.seePlus, color: StayLook.greenText, onTap: PlanGate.seePlus),
                ],
              ],
            ),
          ),
          Gap.h(10),
          ExcludeSemantics(child: Art3D(asset: ListingArt.memo, size: 56)),
        ],
      ),
    );
  }
}
