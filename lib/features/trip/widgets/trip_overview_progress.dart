import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';
import '../trip_strings_overview.dart';
import '../utils/trip_parts.dart';
import 'trip_card.dart';

class TripOverviewProgress extends StatelessWidget {
  const TripOverviewProgress({super.key, required this.parts, this.line});

  final TripParts parts;
  final String? line;

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
    return Semantics(
      container: true,
      label: TripStringsOverview.progressLabel(parts.percent),
      child: Container(
        key: const ValueKey('overview_progress_card'),
        padding: DS.insets(l: 16, t: 14, r: 16, b: 14),
        decoration: BoxDecoration(
          color: DesignColors.surface,
          borderRadius: DS.br(CardRadius.hero),
          boxShadow: DS.shadows(TripLook.cardShadowSoft),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(TripStringsOverview.progressTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(15, FontWeight.w700, Ink3D.title)),
                  Gap.v(10),
                  Row(
                    children: [
                      _Segment(key: const ValueKey('overview_progress_seg_itinerary'), tone: indigo, state: parts.itinerary),
                      Gap.h(6),
                      _Segment(key: const ValueKey('overview_progress_seg_taxi'), tone: ListingTone.sunrise, state: parts.taxi),
                      Gap.h(6),
                      _Segment(key: const ValueKey('overview_progress_seg_stay'), tone: ListingTone.forest, state: parts.stay),
                    ],
                  ),
                  Gap.v(8),
                  Text(
                    line ?? lineOf(parts),
                    key: const ValueKey('overview_progress_line'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Ink3D.text(12.5, FontWeight.w400, Ink3D.sub),
                  ),
                ],
              ),
            ),
            Gap.h(14),
            ExcludeSemantics(
              child: TripProgressRing(
                key: const ValueKey('overview_progress_percent'),
                percent: parts.percent,
                size: 58,
                color: indigo.g2,
                textColor: indigo.text,
              ),
            ),
          ],
        ),
      ),
    );
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
