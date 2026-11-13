import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../models/trip_summary_model.dart';
import '../trip_strings.dart';
import '../trip_strings_summary.dart';
import '../utils/trip_summary_text.dart';

class TripSummaryHero extends StatelessWidget {
  const TripSummaryHero({super.key, required this.record});

  final TripSummaryRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final title = r.title.trim().isEmpty ? r.routeLine : r.title.trim();
    final dates = TripSummaryText.datesOf(r);
    final percent = r.percentDone;
    const white = DesignColors.surface;
    final soft = DesignColors.tint(white, Alpha.v90);
    final tone = ListingTone.indigo;
    final narrow = MediaQuery.sizeOf(context).width < 340;
    final art = narrow ? 92.0 : 112.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 36, 18, 6),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
            decoration: BoxDecoration(
              gradient: tone.gradient,
              borderRadius: kMealsRadius,
              boxShadow: [BoxShadow(color: tone.shadow, offset: const Offset(1.1, 6), blurRadius: 14)],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: percent == null ? art - 4 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(right: percent == null ? 0 : art - 70),
                          child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(21, FontWeight.w700, white, height: 1.25)),
                        ),
                        const SizedBox(height: 4),
                        Text(dates.isEmpty ? TripStringsSummary.datesNotSet : dates,
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w600, white)),
                        if (r.isCompleted)
                          Text(TripStrings.tripCompleted,
                              key: const ValueKey('hero-completed'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Ink3D.text(13, FontWeight.w700, white)),
                        if (r.people > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(TripStringsSummary.travellers(r.people),
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w500, soft)),
                          ),
                      ],
                    ),
                  ),
                ),
                if (percent != null) ...[
                  const SizedBox(width: 12),
                  Padding(
                    padding: EdgeInsets.only(top: art - 40),
                    child: Semantics(
                      label: TripStringsSummary.percentLabel(percent),
                      excludeSemantics: true,
                      child: RingBadge(progress: percent / 100, fill: tone.g2, size: 58),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          right: 30,
          top: 0,
          child: IgnorePointer(
            child: Art3D(asset: ListingArt.luggage, size: art, halo: art + 8, haloColor: DesignColors.tint(white, Alpha.v22)),
          ),
        ),
      ],
    );
  }
}
