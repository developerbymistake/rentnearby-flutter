import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../../../../models/browse_item.dart';
import '../../../trip/trip_strings_final_aa.dart';
import '../models/taxi_ways_models.dart';
import '../taxi_ways_strings.dart';
import '../trip_strings_a6.dart';
import 'journey_driver_card.dart';

class WayPlanCardFrame extends StatelessWidget {
  final WayPlan plan;
  final int planIndex;
  final String? bestReason;
  final VoidCallback onOpen;
  final VoidCallback? onUse;
  final bool useBusy;
  final bool useNote;
  final VoidCallback? onAsk;
  final bool askBusy;
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
    this.onAsk,
    this.askBusy = false,
  });

  ListingTone get _tone => bestReason != null ? ListingTone.coral : [ListingTone.cB, ListingTone.cC, ListingTone.cD][planIndex.abs() % 3];

  List<WayRow> _rows() {
    final rows = <WayRow>[];
    for (var i = 0; i < plan.legs.length; i++) {
      final leg = plan.legs[i];
      rows.add(WayRow.stop(leg.from.name, tag: i > 0 ? TaxiWaysStrings.changeCar : null, filled: i > 0));
      final notes = [
        ?TripStringsA6.legSeats(leg),
        if (leg.carsNeeded > 1) TaxiWaysStrings.carsCount(leg.carsNeeded),
      ];
      rows.add(WayRow.drive(WayPlanStackCard.driverLabel(leg), right: BrowseItem.inr(leg.listedFare), note: notes.isEmpty ? null : notes.join(' · ')));
    }
    if (plan.legs.isNotEmpty) rows.add(WayRow.stop(plan.legs.last.to.name));
    return rows;
  }

  List<WayButton> _buttons() {
    final drivers = [for (final l in plan.legs) ?l.firstDriver];
    final ask = onAsk;
    final use = onUse;
    return [
      for (final (i, d) in drivers.indexed)
        WayButton(
          label: drivers.length > 1 ? TaxiWaysStrings.callName(d.firstName) : TaxiWaysStrings.call,
          onTap: () => JourneyDriverCard.call(d),
          full: drivers.length.isOdd && i == drivers.length - 1,
        ),
      if (ask != null) WayButton(label: TaxiWaysStrings.askPlan(drivers.length), onTap: ask, primary: true, busy: askBusy),
      if (use != null) WayButton(label: TaxiWaysStrings.savePlan, onTap: use, busy: useBusy),
      WayButton(label: TaxiWaysStrings.openJourney, onTap: onOpen, full: true),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final reason = bestReason;
    return WayCard(
      tone: _tone,
      art: plan.carHires >= 3 ? ListingArt.bus : ListingArt.taxi,
      title: TaxiWaysStrings.planName(planIndex),
      subtitle: plan.isDirectCover
          ? TripStringsFinalAa.coverCarsAbout(plan.carHires, plan.total)
          : (reason != null && plan.legs.length > 1
              ? TaxiWaysStrings.carsChangesAbout(plan.carHires, plan.legs.length - 1, plan.total)
              : TaxiWaysStrings.carsAbout(plan.carHires, plan.total)),
      bestLabel: reason != null ? TaxiWaysStrings.bestWay : null,
      rows: _rows(),
      buttons: _buttons(),
      note: useNote && onUse != null ? TaxiWaysStrings.useNote : null,
      onTap: onOpen,
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
  final VoidCallback? onAsk;
  final bool askBusy;

  const WayPlanStackCard({
    super.key,
    required this.plan,
    required this.planIndex,
    required this.onOpen,
    this.bestReason,
    this.onUse,
    this.useBusy = false,
    this.useNote = false,
    this.onAsk,
    this.askBusy = false,
  });

  static String driverLabel(WayLeg leg) {
    final d = leg.firstDriver;
    if (d == null) return '';
    final more = leg.otherCount;
    return more > 0 ? '${d.firstName} ${TaxiWaysStrings.moreDrivers(more)}' : d.firstName;
  }

  @override
  Widget build(BuildContext context) => WayPlanCardFrame(
        plan: plan,
        planIndex: planIndex,
        bestReason: bestReason,
        onOpen: onOpen,
        onUse: onUse,
        useBusy: useBusy,
        useNote: useNote,
        onAsk: onAsk,
        askBusy: askBusy,
        child: const SizedBox.shrink(),
      );
}
