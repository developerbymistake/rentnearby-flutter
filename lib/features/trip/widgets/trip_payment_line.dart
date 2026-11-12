import 'package:flutter/material.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/design/template/fitness_app_theme.dart';
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
      style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 11, letterSpacing: -0.2, color: TripLook.textLight, height: 1.35),
    );
  }
}
