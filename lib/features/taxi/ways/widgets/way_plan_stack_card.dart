import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../config/app_colors.dart';
import '../../../../config/app_shadows.dart';
import '../../../../models/browse_item.dart';
import '../../taxi_option_sets.dart';
import '../models/taxi_ways_models.dart';
import '../taxi_ways_strings.dart';
import 'best_way_mark.dart';

class WayPlanCardFrame extends StatelessWidget {
  final WayPlan plan;
  final int planIndex;
  final String? bestReason;
  final VoidCallback onOpen;
  final Widget child;

  const WayPlanCardFrame({
    super.key,
    required this.plan,
    required this.planIndex,
    required this.onOpen,
    required this.child,
    this.bestReason,
  });

  @override
  Widget build(BuildContext context) {
    final best = bestReason != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: best ? TaxiColors.accent.withValues(alpha: 0.55) : AppColors.divider, width: best ? 1.4 : 1),
            boxShadow: AppShadows.premium(TaxiColors.accent, alpha: 0.07, blur: 12, offset: const Offset(0, 4)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (best) ...[
              BestWayMark(reason: bestReason!),
              const SizedBox(height: 10),
            ],
            Wrap(spacing: 8, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(
                TaxiWaysStrings.planName(planIndex),
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
              ),
              Text(
                TaxiWaysStrings.carsAbout(plan.cars, plan.total),
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight),
              ),
            ]),
            const SizedBox(height: 12),
            child,
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onOpen,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  foregroundColor: TaxiColors.accentDark,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    TaxiWaysStrings.openJourney,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 16),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class WayPlanStackCard extends StatelessWidget {
  final WayPlan plan;
  final int planIndex;
  final String? bestReason;
  final VoidCallback onOpen;

  const WayPlanStackCard({
    super.key,
    required this.plan,
    required this.planIndex,
    required this.onOpen,
    this.bestReason,
  });

  static String driverLabel(WayLeg leg) {
    final d = leg.firstDriver;
    if (d == null) return '';
    final more = leg.otherCount;
    return more > 0 ? '${d.firstName} ${TaxiWaysStrings.moreDrivers(more)}' : d.firstName;
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < plan.legs.length; i++) {
      final leg = plan.legs[i];
      rows.add(_place(leg.from.name, change: i > 0));
      rows.add(_leg(leg));
    }
    if (plan.legs.isNotEmpty) rows.add(_place(plan.legs.last.to.name, last: true));
    return WayPlanCardFrame(
      plan: plan,
      planIndex: planIndex,
      bestReason: bestReason,
      onOpen: onOpen,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
    );
  }

  Widget _place(String name, {bool change = false, bool last = false}) {
    final color = change ? AppColors.warning : TaxiColors.accentDark;
    return Row(children: [
      SizedBox(
        width: 22,
        child: Center(
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: change ? AppColors.warningSurface : (last ? color : Colors.white),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.5),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
      ),
      if (change) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(6)),
          child: const Text(
            TaxiWaysStrings.changeCar,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.warningText),
          ),
        ),
      ],
    ]);
  }

  Widget _leg(WayLeg leg) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 22,
          child: Center(child: Container(width: 2.5, color: TaxiColors.accent.withValues(alpha: 0.45))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              const Icon(Iconsax.car, size: 15, color: TaxiColors.accentDark),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  driverLabel(leg),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textMedium),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                BrowseItem.inr(leg.listedFare),
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: TaxiColors.accentDark),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
