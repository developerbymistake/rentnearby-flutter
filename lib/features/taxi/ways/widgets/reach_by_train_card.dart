import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import '../taxi_ways_strings.dart';

class ReachByTrainCard extends StatelessWidget {
  final String placeName;

  const ReachByTrainCard({super.key, required this.placeName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: TripLook.card(
        color: TripLook.warningSurface,
        radius: TripLook.cardRadius,
        shadowColor: WaysTokens.changeAccent,
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TravelIcon('assets/images/design/travel3d/train.png', size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(TaxiWaysStrings.reachBy(placeName),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: FitnessAppTheme.title.copyWith(fontSize: 13)),
            const SizedBox(height: 2),
            Text(TaxiWaysStrings.reachBody,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: FitnessAppTheme.caption.copyWith(fontSize: 12, color: DesignColors.textGrey)),
          ]),
        ),
      ]),
    );
  }
}
