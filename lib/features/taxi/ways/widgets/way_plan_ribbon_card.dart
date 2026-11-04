import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../config/app_colors.dart';
import '../../../../models/browse_item.dart';
import '../../taxi_option_sets.dart';
import '../models/taxi_ways_models.dart';
import '../taxi_ways_strings.dart';
import 'way_plan_stack_card.dart';

class WayPlanRibbonCard extends StatelessWidget {
  static const double _minRibbonWidth = 300;
  static const double _nodeWidth = 64;
  static const double _band = 24;

  final WayPlan plan;
  final int planIndex;
  final String? bestReason;
  final VoidCallback onOpen;

  const WayPlanRibbonCard({
    super.key,
    required this.plan,
    required this.planIndex,
    required this.onOpen,
    this.bestReason,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final scaled = MediaQuery.textScalerOf(context).scale(10) > 11.5;
    if (plan.legs.length != 2 || screenW < 360 || (scaled && screenW < 400)) {
      return WayPlanStackCard(plan: plan, planIndex: planIndex, bestReason: bestReason, onOpen: onOpen);
    }
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < _minRibbonWidth + 30) {
        return WayPlanStackCard(plan: plan, planIndex: planIndex, bestReason: bestReason, onOpen: onOpen);
      }
      final a = plan.legs[0];
      final b = plan.legs[1];
      return WayPlanCardFrame(
        plan: plan,
        planIndex: planIndex,
        bestReason: bestReason,
        onOpen: onOpen,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _node(a.from.name),
          Expanded(child: _segment(a)),
          _node(a.to.name, change: true),
          Expanded(child: _segment(b)),
          _node(b.to.name, last: true),
        ]),
      );
    });
  }

  Widget _node(String name, {bool change = false, bool last = false}) {
    final color = change ? AppColors.warning : TaxiColors.accentDark;
    return SizedBox(
      width: _nodeWidth,
      child: Column(children: [
        SizedBox(
          height: _band,
          child: Center(
            child: Container(
              width: change ? 16 : 13,
              height: change ? 16 : 13,
              decoration: BoxDecoration(
                color: change ? AppColors.warningSurface : (last ? color : Colors.white),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: change ? 3 : 2.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        if (change)
          const Text(
            TaxiWaysStrings.changeCar,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.warningText),
          ),
      ]),
    );
  }

  Widget _segment(WayLeg leg) {
    return Column(children: [
      SizedBox(
        height: _band,
        child: Stack(alignment: Alignment.center, children: [
          Container(height: 3, color: TaxiColors.accent.withValues(alpha: 0.5)),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: TaxiColors.accent.withValues(alpha: 0.5)),
            ),
            child: const Icon(Iconsax.car, size: 13, color: TaxiColors.accentDark),
          ),
        ]),
      ),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          BrowseItem.inr(leg.listedFare),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w800, color: TaxiColors.accentDark),
        ),
      ),
      Text(
        WayPlanStackCard.driverLabel(leg),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: AppColors.textLight),
      ),
    ]);
  }
}
