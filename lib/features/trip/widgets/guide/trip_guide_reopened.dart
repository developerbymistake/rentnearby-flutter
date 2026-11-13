import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../trip_strings_guide.dart';
import 'trip_guide_nudge.dart';

class TripGuideReopened extends StatelessWidget {
  const TripGuideReopened({super.key, required this.asset, required this.busy, required this.onBooked, required this.onNew, this.tone});

  final String asset;
  final bool busy;
  final VoidCallback onBooked;
  final VoidCallback onNew;
  final ListingTone? tone;

  @override
  Widget build(BuildContext context) => TripGuideTwoButtons(
        tone: tone ?? ListingTone.indigo,
        primaryLabel: TripStringsGuide.bookedMyself,
        secondaryLabel: TripStringsGuide.findNew,
        busy: busy,
        onPrimary: onBooked,
        onSecondary: onNew,
      );
}
