import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/plan_controller.dart';
import '../../../design/design.dart';
import '../../owner_core/plan/gate_keys.dart';
import '../../owner_core/plan/plan_gate.dart';
import '../../owner_core/plan/soft_lock.dart';
import '../home/stay_owner_home_controller.dart';
import '../strings/stay_gate_strings_work.dart';

class StayQuietWeekBanner extends StatelessWidget {
  const StayQuietWeekBanner({super.key});

  static const gateKey = GateKey('gate_g9');

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<PlanController>() && StayOwnerHomeController.maybe == null) return _content();
    return Obx(_content);
  }

  Widget _content() {
        final plans = Get.isRegistered<PlanController>() ? Get.find<PlanController>() : null;
        plans?.myPlan.value;
        final listing = StayOwnerHomeController.maybe?.load.value.valueOrNull?.listing;
        if (!PlanGate.canUpgrade || (listing != null && (listing.areaPaused || listing.tabOff))) return const SizedBox.shrink();
        return Container(
          key: gateKey,
          margin: DS.gapInsets(l: 14, t: 16, r: 14),
          padding: DS.insets(l: 14, t: 12, r: 12, b: 12),
          decoration: BoxDecoration(color: ListingTone.indigo.tint, borderRadius: DS.circular(12)),
          child: Row(
            children: [
              ExcludeSemantics(child: Art3D(asset: ListingArt.crown, size: 36)),
              Gap.h(12),
              Expanded(
                child: Text(
                  StayGateStringsWork.quietWeek,
                  style: Ink3D.text(12.5, FontWeight.w600, ListingTone.indigo.text, height: 1.35, letterSpacing: 0),
                ),
              ),
              Gap.h(8),
              const SeePlusButton(),
            ],
          ),
        );
  }
}
