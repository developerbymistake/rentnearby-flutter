import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../trip_strings_guide.dart';

class TripGuideProgress extends StatelessWidget {
  const TripGuideProgress({super.key, required this.percent, required this.name, required this.index, required this.total, this.tone});

  final int percent;
  final String name;
  final int index;
  final int total;
  final ListingTone? tone;

  @override
  Widget build(BuildContext context) {
    final shown = total <= 0 ? 0 : (index + 1).clamp(1, total);
    final p = percent.clamp(0, 100);
    return Semantics(
      label: '${TripStringsGuide.percent(p)}. ${TripStringsGuide.stepOf(shown, total)}',
      excludeSemantics: true,
      child: GuideStepHeader(
        tone: tone ?? ListingTone.indigo,
        label: TripStringsGuide.stepLabel(name, shown, total),
        progress: p / 100,
      ),
    );
  }
}
