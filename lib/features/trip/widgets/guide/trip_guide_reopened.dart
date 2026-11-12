import 'package:flutter/material.dart';
import '../../trip_strings_guide.dart';
import '../trip_ui.dart';
import 'trip_guide_card.dart';

class TripGuideReopened extends StatelessWidget {
  const TripGuideReopened({super.key, required this.asset, required this.busy, required this.onBooked, required this.onNew});

  final String asset;
  final bool busy;
  final VoidCallback onBooked;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) => TripGuideFrame(
        title: TripStringsGuide.reopenTitle,
        body: TripStringsGuide.reopenBody,
        asset: asset,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TripButton(label: TripStringsGuide.bookedMyself, loading: busy, onPressed: busy ? null : onBooked),
            const SizedBox(height: 10),
            TripButton(label: TripStringsGuide.findNew, outlined: true, onPressed: busy ? null : onNew),
          ],
        ),
      );
}
