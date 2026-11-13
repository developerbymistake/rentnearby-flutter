import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';

class WaysArrangeBar extends StatelessWidget {
  final String arrangeLabel;
  final String skipLabel;
  final VoidCallback onArrange;
  final VoidCallback onSkip;
  final double maxWidth;

  const WaysArrangeBar({
    super.key,
    required this.arrangeLabel,
    required this.skipLabel,
    required this.onArrange,
    required this.onSkip,
    this.maxWidth = 720,
  });

  @override
  Widget build(BuildContext context) => JourneyDock3D(
        maxWidth: maxWidth,
        children: [
          PillButtonRow(children: [
            GradientPillButton(tone: ListingTone.coral, label: arrangeLabel, height: 56, fontSize: 14, onTap: onArrange),
            WhitePillButton(tone: ListingTone.coral, label: skipLabel, height: 56, fontSize: 14, onTap: onSkip),
          ]),
        ],
      );
}
