import 'package:flutter/material.dart';
import 'package:bakhli/design/extra/travel_icon.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/design/template/fitness_app_theme.dart';
import '../models/trip_summary_model.dart';
import '../trip_strings.dart';
import '../trip_strings_mca_a3.dart';

class TripSummaryLegHeader extends StatelessWidget {
  const TripSummaryLegHeader(this.leg, {super.key});

  final TripSummaryLeg leg;

  @override
  Widget build(BuildContext context) {
    final a = leg.startDate;
    final b = leg.endDate;
    final dates = a == null || b == null ? null : TripStringsMcaA3.dateSpan(a, b);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(gradient: TripLook.gradient, shape: BoxShape.circle),
            child: const Center(child: TravelIcon(TravelIcon.place, size: 14)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              TripStrings.joinDots([leg.cityName, dates]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.5, color: TripLook.textMedium),
            ),
          ),
        ],
      ),
    );
  }
}
