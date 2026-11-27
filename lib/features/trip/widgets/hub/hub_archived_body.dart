import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../../models/trip_model.dart';
import '../../trip_strings_archived.dart';
import 'hub_tokens.dart';

// Past card body of an archived trip: the plan is gone, so no ring, steps or strip.
class HubArchivedBody extends StatelessWidget {
  const HubArchivedBody({super.key, required this.trip});

  final TripSummaryModel trip;

  @override
  Widget build(BuildContext context) {
    final style = Ink3D.text(12, FontWeight.w400, HubTokens.grey, height: 1.5, letterSpacing: 0);
    final stats = TripStringsArchived.daysPlaces(trip.dayCount, trip.spotCount);
    return Column(
      key: const ValueKey('hub-card-archived'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(trip.routeLine, key: const ValueKey('hub-card-archived-route'), maxLines: 2, overflow: TextOverflow.ellipsis, style: style),
        if (stats.isNotEmpty) Text(stats, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
        Gap.v(8),
        const StatusPill3D(key: ValueKey('hub-card-archived-tag'), label: TripStringsArchived.archivedTag, status: StatusTone3D.closed, onGradient: false),
      ],
    );
  }
}
