import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../trip_navigation.dart';
import '../trip_strings_v2_find.dart';

class TripBackToPlanBar extends StatelessWidget {
  const TripBackToPlanBar({super.key, this.label = TripStringsV2Find.backToPlan});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DS.insets(l: 12, t: 4, r: 8, b: 4),
      decoration: BoxDecoration(
        color: FitnessAppTheme.white,
        borderRadius: DS.br(TripKit.cardRadiusSmall),
        boxShadow: DS.shadows(TripKit.shadow()),
      ),
      child: Row(
        children: [
          const TravelIcon(TravelIcon.note, size: 18),
          Gap.h(8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontFamily: FitnessAppTheme.fontName,
                  fontSize: DS.f(12),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: FitnessAppTheme.darkerText),
            ),
          ),
          Gap.h(8),
          Material(
            color: FitnessAppTheme.nearlyDarkBlue,
            borderRadius: DS.circular(24),
            child: InkWell(
              onTap: TripNavigation.backToPlan,
              splashColor: FitnessAppTheme.white.withValues(alpha: Alpha.soft),
              highlightColor: Colors.transparent,
              borderRadius: DS.circular(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: DS.s(40)),
                child: Padding(
                  padding: DS.sym(h: 14),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      TripStringsV2Find.backToPlan,
                      style: TextStyle(
                          fontFamily: FitnessAppTheme.fontName,
                          fontSize: DS.f(12.5),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.27,
                          color: FitnessAppTheme.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
