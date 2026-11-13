import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
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
    return TitleRow3D(title: TripStrings.joinDots([leg.cityName, dates]), tone: ListingTone.indigo);
  }
}
