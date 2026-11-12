import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import '../../../../models/browse_item.dart';
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
  final VoidCallback? onUse;
  final bool useBusy;
  final bool useNote;

  const WayPlanRibbonCard({
    super.key,
    required this.plan,
    required this.planIndex,
    required this.onOpen,
    this.bestReason,
    this.onUse,
    this.useBusy = false,
    this.useNote = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final scaled = MediaQuery.textScalerOf(context).scale(10) > 11.5;
    if (plan.legs.length != 2 || screenW < 360 || (scaled && screenW < 400)) {
      return WayPlanStackCard(
        plan: plan,
        planIndex: planIndex,
        bestReason: bestReason,
        onOpen: onOpen,
        onUse: onUse,
        useBusy: useBusy,
        useNote: useNote,
      );
    }
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < _minRibbonWidth + 30) {
        return WayPlanStackCard(
        plan: plan,
        planIndex: planIndex,
        bestReason: bestReason,
        onOpen: onOpen,
        onUse: onUse,
        useBusy: useBusy,
        useNote: useNote,
      );
      }
      final a = plan.legs[0];
      final b = plan.legs[1];
      return WayPlanCardFrame(
        plan: plan,
        planIndex: planIndex,
        bestReason: bestReason,
        onOpen: onOpen,
        onUse: onUse,
        useBusy: useBusy,
        useNote: useNote,
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
    final color = change ? WaysTokens.changeAccent : DesignColors.primary;
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
                color: change ? TripLook.warningSurface : (last ? color : DesignColors.surface),
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
          style: FitnessAppTheme.title.copyWith(fontSize: 11.5),
        ),
        if (change)
          Text(
            TaxiWaysStrings.changeCar,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: FitnessAppTheme.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: TripLook.warningText),
          ),
      ]),
    );
  }

  Widget _segment(WayLeg leg) {
    return Column(children: [
      SizedBox(
        height: _band,
        child: Stack(alignment: Alignment.center, children: [
          Container(height: 3, decoration: BoxDecoration(color: PickKit.taxi, borderRadius: BorderRadius.circular(2))),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: DesignColors.surface,
              shape: BoxShape.circle,
              boxShadow: PickKit.greyShadow(),
            ),
            child: const TravelIcon(TravelIcon.taxi, size: 16),
          ),
        ]),
      ),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          BrowseItem.inr(leg.listedFare),
          style: FitnessAppTheme.title.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: DesignColors.primary),
        ),
      ),
      Text(
        WayPlanStackCard.driverLabel(leg),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: FitnessAppTheme.caption.copyWith(fontSize: 11),
      ),
      if (leg.carsNeeded > 1)
        Text(
          TaxiWaysStrings.carsCount(leg.carsNeeded),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: FitnessAppTheme.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: TripLook.warningText),
        ),
    ]);
  }
}
