import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../taxi_option_sets.dart';
import '../taxi_ways_strings.dart';

class BestWayMark extends StatelessWidget {
  final String reason;

  const BestWayMark({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(gradient: TaxiColors.gradient, borderRadius: BorderRadius.circular(8)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.star_rounded, size: 13, color: Colors.white),
            SizedBox(width: 3),
            Text(
              TaxiWaysStrings.bestWay,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: Colors.white,
              ),
            ),
          ]),
        ),
        Text(
          reason,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMedium),
        ),
      ],
    );
  }
}
