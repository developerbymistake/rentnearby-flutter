import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import '../taxi_ways_strings.dart';

class JourneyChangeStop extends StatelessWidget {
  final String placeName;
  final String? meetingPlace;

  const JourneyChangeStop({super.key, required this.placeName, this.meetingPlace});

  @override
  Widget build(BuildContext context) {
    final meet = meetingPlace;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: TripLook.card(
        color: TripLook.warningSurface,
        radius: TripLook.softRadius,
        shadowColor: WaysTokens.changeAccent,
      ),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(color: DesignColors.surface, shape: BoxShape.circle),
          child: const Icon(Icons.swap_horiz_rounded, size: 20, color: WaysTokens.changeAccent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              placeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FitnessAppTheme.title.copyWith(fontSize: 14),
            ),
            Text(
              TaxiWaysStrings.changeCarHere,
              style: FitnessAppTheme.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: TripLook.warningText),
            ),
            Text(
              meet != null && meet != placeName ? '${TaxiWaysStrings.meetNext} · $meet' : TaxiWaysStrings.meetNext,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: FitnessAppTheme.caption.copyWith(fontSize: 11.5, color: DesignColors.textGrey),
            ),
          ]),
        ),
      ]),
    );
  }
}
