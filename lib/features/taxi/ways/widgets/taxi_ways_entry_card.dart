import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import '../../../../models/place_result_model.dart';
import '../taxi_ways_navigation.dart';
import '../taxi_ways_strings.dart';

class TaxiWaysEntryCard extends StatelessWidget {
  final PlaceResult from;
  final PlaceResult to;
  final bool empty;
  final bool fromMyLocation;

  const TaxiWaysEntryCard({
    super.key,
    required this.from,
    required this.to,
    this.empty = false,
    this.fromMyLocation = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = empty ? TaxiWaysStrings.entryEmptyTitle : TaxiWaysStrings.entryTitle;
    final body = empty ? TaxiWaysStrings.entryEmptyBody : TaxiWaysStrings.entryBody(to.name);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, empty ? 16 : 12, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => TaxiWaysNavigation.openFeed(from: from, to: to, fromMyLocation: fromMyLocation),
          borderRadius: TripLook.cardRadius,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            decoration: TripLook.gradientCard(PickKit.taxi, WaysTokens.changeAccentSoft),
            child: Row(children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: DesignColors.surfaceAlt.withValues(alpha: Alpha.soft),
                  shape: BoxShape.circle,
                ),
                child: const TravelIcon(TravelIcon.taxi, size: 36),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    title,
                    style: FitnessAppTheme.title.copyWith(fontSize: 15, color: DesignColors.surface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FitnessAppTheme.caption.copyWith(fontSize: 11.5, color: DesignColors.surface.withValues(alpha: Alpha.high)),
                  ),
                ]),
              ),
              const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.chevron_right_rounded, size: 24, color: DesignColors.surface),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
