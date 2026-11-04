import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../trip_strings.dart';

class TripPaymentLine extends StatelessWidget {
  const TripPaymentLine({super.key, this.text = TripStrings.stayPayLine});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11, color: AppColors.textLight, height: 1.35),
    );
  }
}
