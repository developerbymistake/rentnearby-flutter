import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../trip_strings_guide.dart';

class TripGuideProgress extends StatelessWidget {
  const TripGuideProgress({super.key, required this.percent, required this.name, required this.index, required this.total, this.tone, this.pendingNames = const []});

  final int percent;
  final String name;
  final int index;
  final int total;
  final ListingTone? tone;
  final List<String> pendingNames;

  @override
  Widget build(BuildContext context) {
    final shown = total <= 0 ? 0 : (index + 1).clamp(1, total);
    final p = percent.clamp(0, 100);
    final header = GuideStepHeader(
      tone: tone ?? ListingTone.indigo,
      label: TripStringsGuide.stepLabel(name, shown, total),
      progress: p / 100,
    );
    final tag = pendingNames.isEmpty ? '' : '${TripStringsGuide.pendingTag}: ${pendingNames.join(', ')}';
    return Semantics(
      label: '${TripStringsGuide.percent(p)}. ${TripStringsGuide.stepOf(shown, total)}${tag.isEmpty ? '' : '. $tag'}',
      excludeSemantics: true,
      child: tag.isEmpty
          ? header
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                header,
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Text(tag, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w600, Ink3D.grey, letterSpacing: 0)),
                ),
              ],
            ),
    );
  }
}
