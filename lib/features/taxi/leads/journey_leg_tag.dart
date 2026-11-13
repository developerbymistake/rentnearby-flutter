import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_taxi_owner.dart';
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: TaxiOwnerLook.cream, borderRadius: BorderRadius.circular(12)),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11.5, FontWeight.w700, TaxiOwnerLook.creamText, letterSpacing: 0)),
      );
}
