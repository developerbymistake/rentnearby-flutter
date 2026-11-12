import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../models/trip_summary_model.dart';
import '../trip_strings.dart';
import '../trip_strings_summary.dart';
import '../utils/trip_summary_text.dart';
import 'trip_card.dart';

class TripSummaryHero extends StatelessWidget {
  const TripSummaryHero({super.key, required this.record});

  final TripSummaryRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final title = r.title.trim().isEmpty ? r.routeLine : r.title.trim();
    final dates = TripSummaryText.datesOf(r);
    final percent = r.percentDone;
    const white = FitnessAppTheme.white;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: KitTone.trip.gradient,
        borderRadius: CardRadius.tile,
        boxShadow: ShadowTokens.glow(KitTone.trip.glow),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 20, fontWeight: FontWeight.w800, color: white),
                ),
                const SizedBox(height: 4),
                Text(
                  dates.isEmpty ? TripStringsSummary.datesNotSet : dates,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w600, color: white),
                ),
                if (r.isCompleted)
                  Text(
                    TripStrings.tripCompleted,
                    key: const ValueKey('hero-completed'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 13, fontWeight: FontWeight.w700, color: white),
                  ),
                if (r.people > 0)
                  Text(
                    TripStringsSummary.travellers(r.people),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 13, color: white),
                  ),
              ],
            ),
          ),
          if (percent != null) ...[
            const SizedBox(width: 12),
            Semantics(
              label: TripStringsSummary.percentLabel(percent),
              excludeSemantics: true,
              child: TripProgressRing(percent: percent, size: 68, stroke: 7, fill: DesignColors.surface),
            ),
          ],
        ],
      ),
    );
  }
}
