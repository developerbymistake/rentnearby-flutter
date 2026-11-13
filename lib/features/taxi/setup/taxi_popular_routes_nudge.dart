import 'package:flutter/material.dart';
import '../../../design/design.dart';
import '../ways/taxi_ways_strings.dart';

class TaxiPopularRoutesNudge extends StatelessWidget {
  final VoidCallback onTap;

  const TaxiPopularRoutesNudge({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) => FormNoteCard(
        tone: ListingTone.coral,
        art: ListingArt.compass,
        title: TaxiWaysStrings.nudgeTitle,
        body: TaxiWaysStrings.nudgeBody,
        onTap: onTap,
      );
}
