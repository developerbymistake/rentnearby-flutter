import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_customize_look.dart';
import 'package:flutter/material.dart';
import '../trip_strings_overview.dart';
import '../utils/trip_parts.dart';
import 'trip_card.dart';

class TripOverviewProgress extends StatelessWidget {
  const TripOverviewProgress({super.key, required this.parts, required this.title, required this.line, this.status, this.showProgress = true});

  final TripParts parts;
  final String title;
  final String line;
  final String? status;
  final bool showProgress;

  static String lineOf(TripParts p) {
    final taxi = p.taxi == TripPartState.open;
    final stay = p.stay == TripPartState.open;
    if (p.itinerary == TripPartState.open) return TripStringsOverview.progressNoPlan;
    if (taxi && stay) return TripStringsOverview.progressBothOpen;
    if (stay) return TripStringsOverview.progressStayOpen;
    if (taxi) return TripStringsOverview.progressTaxiOpen;
    return TripStringsOverview.progressAllSet;
  }

  @override
  Widget build(BuildContext context) {
    final indigo = ListingTone.indigo;
    final narrow = MediaQuery.sizeOf(context).width < Form3D.narrow;
    final card = Container(
      key: showProgress ? const ValueKey('overview_progress_card') : null,
      padding: DS.insets(l: 12, t: 12, r: 16, b: 12),
      decoration: BoxDecoration(
        gradient: TripCustomizeLook.tripCardGradient,
        border: Border.all(color: TripCustomizeLook.tripCardBorder, width: DS.s(1)),
        borderRadius: DS.br(CardRadius.hero),
        boxShadow: DS.shadows(TripCustomizeLook.tripCardShadow),
      ),
      child: Row(
        children: [
          SizedBox(
            width: DS.s(narrow ? 48 : 58),
            height: DS.s(narrow ? 48 : 58),
            child: Center(
              child: Art3D(
                asset: ListingArt.luggage,
                size: narrow ? 34 : 40,
                halo: narrow ? 48 : 58,
                haloColor: DesignColors.tint(indigo.g2, Alpha.tint),
                shadowBlur: 4,
                shadowOffset: const Offset(2, 3),
              ),
            ),
          ),
          Gap.h(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  key: const ValueKey('overview_trip_name'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Ink3D.text(17, FontWeight.w700, TripCustomizeLook.tripCardName),
                ),
                if (showProgress) ...[
                  Gap.v(8),
                  Row(
                    children: [
                      _Segment(key: const ValueKey('overview_progress_seg_itinerary'), tone: indigo, state: parts.itinerary),
                      Gap.h(6),
                      _Segment(key: const ValueKey('overview_progress_seg_taxi'), tone: ListingTone.sunrise, state: parts.taxi),
                      Gap.h(6),
                      _Segment(key: const ValueKey('overview_progress_seg_stay'), tone: ListingTone.forest, state: parts.stay),
                    ],
                  ),
                  Gap.v(6),
                ],
                Text(
                  line,
                  key: const ValueKey('overview_trip_line'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Ink3D.text(12.5, FontWeight.w400, TripCustomizeLook.tripCardSub, height: 1.5),
                ),
              ],
            ),
          ),
          if (showProgress) ...[
            Gap.h(12),
            ExcludeSemantics(
              child: TripProgressRing(
                key: const ValueKey('overview_progress_percent'),
                percent: parts.percent,
                size: 50,
                color: indigo.g2,
                textColor: indigo.text,
              ),
            ),
          ],
        ],
      ),
    );
    if (!showProgress) return card;
    return Semantics(container: true, label: TripStringsOverview.progressLabel(parts.percent, status ?? lineOf(parts)), child: card);
  }
}

class _Segment extends StatelessWidget {
  const _Segment({super.key, required this.tone, required this.state});

  final ListingTone tone;
  final TripPartState state;

  @override
  Widget build(BuildContext context) {
    final decoration = switch (state) {
      TripPartState.arranged => BoxDecoration(gradient: tone.gradient, borderRadius: DS.circular(6)),
      TripPartState.skipped => BoxDecoration(color: DesignColors.tint(tone.g2, Alpha.v45), borderRadius: DS.circular(6)),
      TripPartState.open => BoxDecoration(color: DesignColors.tint(tone.g2, Alpha.tint), borderRadius: DS.circular(6)),
    };
    return Expanded(
      child: Container(
        height: DS.s(10),
        alignment: Alignment.center,
        decoration: decoration,
        child: state == TripPartState.skipped
            ? Icon(Icons.check_rounded, key: const ValueKey('overview_progress_tick'), size: DS.s(9), color: tone.text)
            : null,
      ),
    );
  }
}
