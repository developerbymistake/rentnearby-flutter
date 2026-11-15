import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/design/extra/ways_kit.dart';
import '../taxi_ways_strings.dart';

class BestWayMark extends StatelessWidget {
  final String reason;

  const BestWayMark({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DS.gh(8),
      runSpacing: DS.gv(4),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: DS.sym(h: 9, v: 4),
          decoration: BoxDecoration(
            gradient: PickKit.taxiGradient,
            borderRadius: DS.br(WaysKit.chipRadius),
            boxShadow: DS.shadows(TripLook.shadowFor(PickKit.taxi)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const TravelIcon(TravelIcon.star, size: 13),
            SizedBox(width: DS.s(3)),
            Text(
              TaxiWaysStrings.bestWay,
              style: FitnessAppTheme.caption.copyWith(
                fontSize: DS.f(11),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: DesignColors.surface,
              ),
            ),
          ]),
        ),
        Text(
          reason,
          style: FitnessAppTheme.subtitle.copyWith(fontSize: DS.f(12), fontWeight: FontWeight.w600, color: DesignColors.textGrey),
        ),
      ],
    );
  }
}
