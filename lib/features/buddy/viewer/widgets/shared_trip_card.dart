import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../trip/trip_strings_archived.dart';
import '../../../trip/utils/trip_clock.dart';
import '../../../trip/widgets/hub/hub_ring.dart';
import '../../../trip/widgets/hub/hub_tokens.dart';
import '../../buddy_navigation.dart';
import '../../shared/buddy_format.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/buddy_badge.dart';
import '../models/viewer_models.dart' as vm;
import '../viewer_rules.dart';
import '../viewer_strings.dart';
import 'viewer_card_parts.dart';

class SharedTripCard extends StatelessWidget {
  const SharedTripCard({super.key, required this.trip, this.onOpen});

  final vm.SharedTripCard trip;
  final VoidCallback? onOpen;

  void _open() => onOpen != null ? onOpen!() : BuddyNavigation.openTripView(trip.tripId);

  @override
  Widget build(BuildContext context) {
    final t = trip;
    final dates = BuddyFormat.dateRange(t.startDate, t.endDate);
    final foot = ViewerRules.footLine(start: t.startDate, end: t.endDate, dayCount: t.dayCount, today: TripClock.today());
    return ViewerHubCard(
      key: ValueKey('shared_card_${t.tripId}'),
      onTap: _open,
      children: [
        ViewerCardTitle(t.title),
        ViewerMetaRow(badge: ViewerStrings.viewer, tone: BuddyBadgeTone.view, line: ViewerStrings.byLine(t.ownerName, dates)),
        if (t.archived)
          Padding(
            padding: EdgeInsets.only(bottom: DS.gv(10)),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: StatusPill3D(key: ValueKey('shared_card_archived'), label: TripStringsArchived.archivedTag, status: StatusTone3D.closed, onGradient: false),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Stat(art: BuddyArt.calendar, value: ViewerStrings.dayCount(t.dayCount), label: ViewerStrings.places(t.spotCount)),
                  Gap.v(12),
                  _Stat(art: BuddyArt.panda, value: '${t.travellerCount}', label: ViewerStrings.travellersWord(t.travellerCount)),
                  Gap.v(12),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: DS.s(2)),
              child: HubRing(
                percent: t.progressPercent,
                size: 104,
                thickness: 11,
                arc: BuddyLook.tealStart,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ViewerStrings.percent(t.progressPercent), style: Ink3D.text(24, FontWeight.w700, HubTokens.ink, height: 1, letterSpacing: 0)),
                    Text(ViewerStrings.ready, style: Ink3D.text(11, FontWeight.w400, HubTokens.grey, height: 21 / 11, letterSpacing: 0)),
                  ],
                ),
              ),
            ),
          ],
        ),
        ViewerBars(stay: ViewerBarState.of(t.stayState), taxi: ViewerBarState.of(t.taxiState)),
        ViewerFootStrip(key: ValueKey('shared_open_${t.tripId}'), small: foot, title: ViewerStrings.openThePlan, onTap: _open),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.art, required this.value, required this.label});

  final String art;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: DS.s(34),
            height: DS.s(34),
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: HubTokens.chipBg, shape: BoxShape.circle),
            child: ExcludeSemantics(child: Image.asset(art, width: DS.s(22), height: DS.s(22))),
          ),
          Gap.h(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Ink3D.text(20, FontWeight.w700, HubTokens.ink, height: 1.05, letterSpacing: 0)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w400, HubTokens.grey, height: 1.75, letterSpacing: 0)),
              ],
            ),
          ),
        ],
      );
}
