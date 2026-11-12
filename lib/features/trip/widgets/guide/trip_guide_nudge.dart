import 'package:flutter/material.dart';
import '../../trip_strings_guide.dart';
import '../trip_ui.dart';
import 'trip_guide_card.dart';

class TripGuideNudge extends StatelessWidget {
  const TripGuideNudge({
    super.key,
    required this.asset,
    required this.name,
    required this.busy,
    required this.onBooked,
    required this.onNew,
  });

  final String asset;
  final String name;
  final bool busy;
  final VoidCallback onBooked;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) => TripGuideFrame(
        title: TripStringsGuide.nudgeTitle(name.isEmpty ? TripStringsGuide.nudgeNameFallback : name),
        body: TripStringsGuide.nudgeBody,
        asset: asset,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TripButton(label: TripStringsGuide.markBooked, loading: busy, onPressed: busy ? null : onBooked),
            const SizedBox(height: 10),
            TripButton(label: TripStringsGuide.chooseNew, outlined: true, onPressed: busy ? null : onNew),
          ],
        ),
      );
}
