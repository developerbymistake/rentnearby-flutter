import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../config/app_colors.dart';
import '../../../../config/app_shadows.dart';
import '../../../../models/browse_item.dart';
import '../../../trip/trip_strings_final_aa.dart';
import '../../../trip/trip_strings_steps_a3.dart';
import '../../taxi_option_sets.dart';
import '../models/taxi_ways_models.dart';
import '../taxi_ways_strings.dart';
import '../trip_strings_a6.dart';
import 'best_way_mark.dart';
import 'journey_driver_card.dart';

class WayPlanCardFrame extends StatelessWidget {
  final WayPlan plan;
  final int planIndex;
  final String? bestReason;
  final VoidCallback onOpen;
  final VoidCallback? onUse;
  final bool useBusy;
  final bool useNote;
  final Widget child;

  const WayPlanCardFrame({
    super.key,
    required this.plan,
    required this.planIndex,
    required this.onOpen,
    required this.child,
    this.bestReason,
    this.onUse,
    this.useBusy = false,
    this.useNote = false,
  });

  Widget _calls() {
    final drivers = [for (final l in plan.legs) if (l.firstDriver != null) l.firstDriver!];
    if (drivers.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final d in drivers)
          OutlinedButton.icon(
            onPressed: () => JourneyDriverCard.call(d),
            icon: const Icon(Iconsax.call, size: 16, color: TaxiColors.accentDark),
            label: Text(drivers.length > 1 ? TaxiWaysStrings.callName(d.firstName) : TaxiWaysStrings.call,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: TaxiColors.accentDark)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              side: BorderSide(color: TaxiColors.accent.withValues(alpha: 0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
      ]),
    );
  }

  Widget _use() {
    final use = onUse;
    if (use == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ElevatedButton(
          onPressed: useBusy ? null : use,
          style: ElevatedButton.styleFrom(
            backgroundColor: TaxiColors.accentDark,
            foregroundColor: Colors.white,
            disabledBackgroundColor: TaxiColors.accent.withValues(alpha: 0.5),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: useBusy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text(TripStringsStepsA3.useForMyTrip,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        if (useNote)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(TaxiWaysStrings.useNote,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
          ),
      ]),
    );
  }

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
                plan.isDirectCover
                    ? TripStringsFinalAa.coverCarsAbout(plan.carHires, plan.total)
                    : TaxiWaysStrings.carsAbout(plan.carHires, plan.total),
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight),
              ),
            ]),
            const SizedBox(height: 12),
            child,
            _calls(),
            _use(),
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
  final VoidCallback? onUse;
  final bool useBusy;
  final bool useNote;

  const WayPlanStackCard({
    super.key,
    required this.plan,
    required this.planIndex,
    required this.onOpen,
    this.bestReason,
    this.onUse,
    this.useBusy = false,
    this.useNote = false,
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
      onUse: onUse,
      useBusy: useBusy,
      useNote: useNote,
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
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
              if (TripStringsA6.legSeats(leg) != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 21),
                  child: Text(
                    TripStringsA6.legSeats(leg)!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warningText),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}
