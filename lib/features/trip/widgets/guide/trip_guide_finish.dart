import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../trip_strings_guide.dart';
import '../trip_ui.dart';
import 'trip_guide_card.dart';

class TripGuideFinish extends StatelessWidget {
  const TripGuideFinish({super.key, required this.onSummary, required this.onOverview, this.arranged = true});

  final bool arranged;
  final VoidCallback onSummary;
  final VoidCallback onOverview;

  @override
  Widget build(BuildContext context) => TripGuideFrame(
        title: arranged ? TripStringsGuide.finishTitle : TripStringsGuide.finishSavedTitle,
        body: arranged ? TripStringsGuide.finishBody : TripStringsGuide.finishSavedBody,
        asset: TravelIcon.luggage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (arranged) ...[
              TripButton(label: TripStringsGuide.openSummary, onPressed: onSummary),
              const SizedBox(height: 10),
              TripButton(label: TripStringsGuide.overview, outlined: true, onPressed: onOverview),
            ] else ...[
              TripButton(label: TripStringsGuide.seeStillToDo, onPressed: onOverview),
              const SizedBox(height: 10),
              TripButton(label: TripStringsGuide.openSummary, outlined: true, onPressed: onSummary),
            ],
          ],
        ),
      );
}
