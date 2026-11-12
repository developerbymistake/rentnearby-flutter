import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import '../../../../models/browse_item.dart';
import '../../../trip/trip_strings_final_aa.dart';
import '../../../trip/trip_strings_steps_a3.dart';
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
      child: Wrap(spacing: 8, children: [
        for (final d in drivers)
          PillAction(
            onTap: () => JourneyDriverCard.call(d),
            icon: const Icon(Icons.call_rounded, size: 16, color: DesignColors.primary),
            label: drivers.length > 1 ? TaxiWaysStrings.callName(d.firstName) : TaxiWaysStrings.call,
            tone: KitTone.taxi,
            maxWidth: 200,
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
        PrimaryButton(
          label: TripStringsStepsA3.useForMyTrip,
          onPressed: useBusy ? null : use,
          loading: useBusy,
          tone: KitTone.taxi,
        ),
        if (useNote)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(TaxiWaysStrings.useNote, textAlign: TextAlign.center, style: TypeTokens.caption),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final best = bestReason != null;
    return SectionTile(
      onTap: onOpen,
      selected: best,
      tone: KitTone.taxi,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (best) ...[
          BestWayMark(reason: bestReason!),
          const SizedBox(height: 10),
        ],
        Wrap(spacing: 8, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(TaxiWaysStrings.planName(planIndex), style: TypeTokens.style(14, FontWeight.w700, color: DesignColors.textStrong)),
          Text(
            plan.isDirectCover
                ? TripStringsFinalAa.coverCarsAbout(plan.carHires, plan.total)
                : TaxiWaysStrings.carsAbout(plan.carHires, plan.total),
            style: TypeTokens.style(12, FontWeight.w600, color: DesignColors.textSecondary),
          ),
        ]),
        const SizedBox(height: 12),
        child,
        _calls(),
        _use(),
        Align(
          alignment: Alignment.centerRight,
          child: PillAction(
            label: TaxiWaysStrings.openJourney,
            tone: KitTone.taxi,
            onTap: onOpen,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: DesignColors.primary),
          ),
        ),
      ]),
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
    final color = change ? WaysTokens.changeAccent : DesignColors.primary;
    return Row(children: [
      SizedBox(
        width: 22,
        child: Center(
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: change ? TripLook.warningSurface : (last ? color : DesignColors.surface),
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
          style: FitnessAppTheme.title.copyWith(fontSize: 13),
        ),
      ),
      if (change) ...[
        const SizedBox(width: 8),
        KitTagChip(TaxiWaysStrings.changeCar, color: DesignColors.warnDeep),
      ],
    ]);
  }

  Widget _leg(WayLeg leg) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 22,
          child: Center(child: Container(width: 2.5, decoration: BoxDecoration(color: PickKit.taxi, borderRadius: BorderRadius.circular(2)))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const TravelIcon(TravelIcon.taxi, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    driverLabel(leg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FitnessAppTheme.caption.copyWith(fontSize: 12, color: DesignColors.textGrey),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  BrowseItem.inr(leg.listedFare),
                  style: FitnessAppTheme.title.copyWith(fontSize: 13, color: DesignColors.primary),
                ),
              ]),
              if (TripStringsA6.legSeats(leg) != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 22),
                  child: Text(
                    TripStringsA6.legSeats(leg)!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FitnessAppTheme.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: TripLook.warningText),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}
