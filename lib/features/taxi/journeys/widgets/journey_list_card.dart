import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
import '../../../trip/trip_strings_mcb_a3.dart';
import '../../../trip/trip_strings_steps_a3.dart';
import '../../ways/taxi_ways_strings.dart';
import '../journey_models.dart';

const String _nbsp = '\u00A0';

class JourneyListCard extends StatelessWidget {
  final SavedJourney journey;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onAsk;
  final void Function(SavedJourneyLeg leg, JourneyContact backup) onReplace;

  const JourneyListCard({
    super.key,
    required this.journey,
    required this.busy,
    required this.onOpen,
    required this.onAsk,
    required this.onReplace,
  });

  static String _tripChip(SavedJourney j) {
    final day = j.tripTravelDay;
    return j.isSegment && day != null ? TripStringsMcbA3.inYourTrip(day) : TripStringsStepsA3.inYourTrip;
  }

  static ListingTone toneOf(SavedJourney j) => switch (j.status) {
        JourneyStatus.driverUnavailable => ListingTone.cF,
        JourneyStatus.completed => ListingTone.cB,
        _ => ListingTone.cA,
      };

  static Color? inkOf(SavedJourney j) => switch (j.status) {
        JourneyStatus.ready => JourneyInk.ok,
        _ => null,
      };

  List<JourneyCell?> _cells() {
    final j = journey;
    const open = Icons.arrow_forward_rounded;
    final openCell = JourneyCell(label: TaxiWaysStrings.open, icon: open, onTap: onOpen);
    if (j.isCompleted) return const [null, null];
    if (j.status == JourneyStatus.driverUnavailable) {
      final leg = j.firstUnavailable;
      final backup = leg?.readyBackup;
      if (leg != null && backup != null) {
        return [
          JourneyCell(
            label: TaxiWaysStrings.replaceWith(backup.driverName),
            icon: Icons.swap_horiz_rounded,
            busy: busy,
            onTap: busy ? null : () => onReplace(leg, backup),
          ),
        ];
      }
      return [openCell, null];
    }
    if (j.status == JourneyStatus.notAsked) {
      return [openCell, JourneyCell(label: TaxiWaysStrings.askDrivers, icon: Icons.mail_outline_rounded, onTap: onAsk)];
    }
    return [openCell, null];
  }

  @override
  Widget build(BuildContext context) {
    final j = journey;
    final leg = j.firstUnavailable;
    final note = j.status == JourneyStatus.driverUnavailable && leg != null
        ? (leg.readyBackup == null
            ? TaxiWaysStrings.pausedNoBackup(leg.driver.driverName)
            : TaxiWaysStrings.pausedBody(leg.driver.driverName, leg.readyBackup!.driverName))
        : null;
    final first = j.legs.isEmpty ? null : j.legs.first.driver;
    final route = JourneyFormat.route(j);
    return JourneyCard3D(
      tone: toneOf(j),
      art: JourneyArt.forVehicle(first?.vehicleTypeName, first?.seats),
      tag: j.tripId == null ? null : _tripChip(j),
      title: route,
      subtitle: [JourneyFormat.line(j).split(' · ').map((e) => e.replaceAll(' ', _nbsp)).join(' · ')],
      pill: JourneyPill3D(label: JourneyFormat.statusText(j), ink: inkOf(j)),
      note: [?note],
      cells: _cells(),
      onTap: onOpen,
      semanticsLabel: route,
    );
  }
}
