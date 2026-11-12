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
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
      decoration: BoxDecoration(
        color: FitnessAppTheme.white,
        borderRadius: TripKit.cardRadiusSmall,
        boxShadow: TripKit.shadow(),
      ),
      child: Row(
        children: [
          const TravelIcon(TravelIcon.note, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: FitnessAppTheme.fontName,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: FitnessAppTheme.darkerText),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: FitnessAppTheme.nearlyDarkBlue,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: TripNavigation.backToPlan,
              splashColor: FitnessAppTheme.white.withValues(alpha: Alpha.soft),
              highlightColor: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      TripStringsV2Find.backToPlan,
                      style: TextStyle(
                          fontFamily: FitnessAppTheme.fontName,
                          fontSize: 12.5,
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
