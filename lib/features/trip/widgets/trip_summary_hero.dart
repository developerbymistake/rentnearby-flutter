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
    final artRaw = narrow ? 92.0 : 112.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(DS.s(18), DS.s(36), DS.s(18), DS.gv(6)),
          child: Container(
            padding: DS.insets(l: 20, t: 20, r: 16, b: 16),
            decoration: BoxDecoration(
              gradient: tone.gradient,
              borderRadius: DS.br(kMealsRadius),
              boxShadow: [BoxShadow(color: tone.shadow, offset: DS.shadowOffset(const Offset(1.1, 6)), blurRadius: DS.shadowBlur(14))],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: percent == null ? DS.s(artRaw - 4) : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(right: percent == null ? 0 : DS.s(artRaw - 70)),
                          child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Ink3D.text(21, FontWeight.w700, white, height: 1.25)),
                        ),
                        Gap.v(4),
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
                            padding: EdgeInsets.only(top: DS.s(4)),
                            child: Text(TripStringsSummary.travellers(r.people),
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w500, soft)),
                          ),
                      ],
                    ),
                  ),
                ),
                if (percent != null) ...[
                  Gap.h(12),
                  Padding(
                    padding: EdgeInsets.only(top: DS.s(artRaw - 40)),
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
          right: DS.s(30),
          top: 0,
          child: IgnorePointer(
            child: Art3D(asset: ListingArt.luggage, size: artRaw, halo: artRaw + 8, haloColor: DesignColors.tint(white, Alpha.v22)),
          ),
        ),
      ],
    );
  }
}
