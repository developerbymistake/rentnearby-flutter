import 'package:flutter/material.dart';
import '../../../design/design.dart';
import '../ways/taxi_ways_strings.dart';

class TaxiPopularRoutesNudge extends StatelessWidget {
  final VoidCallback onTap;

  const TaxiPopularRoutesNudge({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: FitnessAppTheme.white,
        borderRadius: PickKit.cardRadius,
        boxShadow: PickKit.greyShadow(),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: PickKit.cardRadius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: PickKit.taxiGradient,
                    boxShadow: PickKit.shadow(PickKit.taxiDark),
                  ),
                  child: Image.asset(TravelIcon.route),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(TaxiWaysStrings.nudgeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TripKit.text(14).copyWith(letterSpacing: 0.2)),
                    Text(TaxiWaysStrings.nudgeBody,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TripKit.text(12, color: FitnessAppTheme.grey)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20, color: FitnessAppTheme.nearlyDarkBlue),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
