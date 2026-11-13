import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../trip_strings_guide.dart';
import 'trip_guide_card.dart';

class TripGuideNudge extends StatelessWidget {
  const TripGuideNudge({
    super.key,
    required this.asset,
    required this.name,
    required this.busy,
    required this.onBooked,
    required this.onNew,
    this.tone,
  });

  final String asset;
  final String name;
  final bool busy;
  final VoidCallback onBooked;
  final VoidCallback onNew;
  final ListingTone? tone;

  static String titleFor(String name) => TripStringsGuide.nudgeTitle(name.isEmpty ? TripStringsGuide.nudgeNameFallback : name);

  @override
  Widget build(BuildContext context) => TripGuideTwoButtons(
        tone: tone ?? ListingTone.indigo,
        primaryLabel: TripStringsGuide.markBooked,
        secondaryLabel: TripStringsGuide.chooseNew,
        busy: busy,
        onPrimary: onBooked,
        onSecondary: onNew,
      );
}

class TripGuideTwoButtons extends StatelessWidget {
  const TripGuideTwoButtons({
    super.key,
    required this.tone,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.busy,
    required this.onPrimary,
    required this.onSecondary,
  });

  final ListingTone tone;
  final String primaryLabel;
  final String secondaryLabel;
  final bool busy;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TripGuideSheetButton(label: primaryLabel, tone: tone, loading: busy, onTap: busy ? null : onPrimary),
            const SizedBox(height: 12),
            TripGuideSheetButton(label: secondaryLabel, tone: tone, primary: false, onTap: busy ? null : onSecondary),
          ],
        ),
      );
}
