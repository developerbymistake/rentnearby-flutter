import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import '../../trip/models/trip_enquiry_model.dart';
import '../ways/taxi_ways_strings.dart';

class JourneyLegTag extends StatelessWidget {
  final String text;

  const JourneyLegTag({super.key, required this.text});

  static final RegExp _car = RegExp(r'^Car (\d) of (\d):');

  static String? fromLead(TripEnquiryModel e) {
    final m = _car.firstMatch(e.context.text);
    if (m == null) return null;
    return TaxiWaysStrings.carOf(int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  @override
  Widget build(BuildContext context) =>
      JourneyPill(text: text, fg: DesignColors.textPrimary, bg: TripLook.warningSurface);
}
