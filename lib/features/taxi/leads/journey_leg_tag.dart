import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warningText)),
    );
  }
}
