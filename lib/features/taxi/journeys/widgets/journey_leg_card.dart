import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
import '../../../../models/browse_item.dart';
import '../../../../utils/contact_launcher.dart';
import '../../../trip/trip_strings_fin_b1.dart';
import '../../../trip/trip_strings_final_aa.dart';
import '../../ways/taxi_ways_strings.dart';
import '../../ways/trip_strings_a6.dart';
import '../../ways/trip_strings_mcb_a2.dart';
import '../journey_models.dart';
import '../journey_strings.dart';

class JourneyLegCard extends StatelessWidget {
  final SavedJourneyLeg leg;
  final int people;
  final Color color;
  final bool busy;
  final bool canChange;
  final VoidCallback onChangeDriver;
  final void Function(JourneyContact backup) onReplace;
  final int legCount;

  const JourneyLegCard({
    super.key,
    required this.leg,
    this.people = 0,
    required this.color,
    required this.busy,
    required this.canChange,
    required this.onChangeDriver,
    required this.onReplace,
    this.legCount = 0,
  });

  static bool isUnavailable(SavedJourneyLeg leg) => !leg.driverAvailable && !leg.isBooked;

  static ListingTone toneOf(SavedJourneyLeg leg) => JourneyInk.legTone(leg.legIndex, unavailable: isUnavailable(leg));

  (String, Color?) _pill() {
    if (leg.isBooked) {
      return leg.isConfirmedByBoth ? (TripStringsMcbA2.confirmedByBoth, JourneyInk.ok) : (TripStringsMcbA2.bookedByYou, JourneyInk.booked);
    }
    if (isUnavailable(leg)) return (JourneyStrings.unavailableTag, JourneyInk.bad);
    final text = JourneyFormat.statusLine(leg, DateTime.now());
    return switch (leg.lastKnownStatus) {
      LegStatus.free => (text, JourneyInk.ok),
      LegStatus.notFree => (text, JourneyInk.bad),
      _ => (text, null),
    };
  }

  @override
  Widget build(BuildContext context) {
    final d = leg.driver;
    final booked = leg.isBooked;
    final unavailable = isUnavailable(leg);
    final change = canChange && !booked;
    final backup = leg.readyBackup;
    final backupNames = leg.backups.where((b) => b.available).map((b) => b.driverName).toList();
    final fare = leg.listedFare;
    final previous = leg.previousFare;
    final quoted = leg.lastQuotedFare;
    final cars = people > 0 ? leg.carsOf(people) : 1;
    final coverNames = leg.coverDrivers.map((c) => c.driverName).where((n) => n.isNotEmpty).toList();
    final (pillText, pillInk) = _pill();
    final note = <String>[
      if (booked && leg.agreedFare != null) TripStringsFinB1.agreedFare(BrowseItem.inr(leg.agreedFare!)),
      if (!booked && !unavailable && leg.lastKnownStatus == LegStatus.free && quoted != null) JourneyStrings.driverQuote(quoted),
      if (previous != null && fare != null && previous != fare) TaxiWaysStrings.fareChanged(previous, fare),
      if (cars > 1)
        [
          leg.seatsNote ?? TripStringsA6.seatsNote(d.seats, cars, people),
          if (coverNames.isNotEmpty) TripStringsFinalAa.withCars(coverNames),
        ].join(' · '),
      if (!unavailable && !d.hasPhone && !d.hasWhatsApp) JourneyStrings.noNumber,
      if (!booked && backupNames.isNotEmpty) TaxiWaysStrings.backup(backupNames),
    ];
    final callCell = JourneyCell(
      label: TaxiWaysStrings.call,
      icon: Icons.call_rounded,
      onTap: d.hasPhone ? () => ContactLauncher.call(d.phone!) : null,
    );
    final List<JourneyCell?> cells;
    if (unavailable) {
      cells = [
        backup != null
            ? JourneyCell(
                label: TaxiWaysStrings.replaceWith(backup.driverName),
                icon: Icons.swap_horiz_rounded,
                busy: busy,
                onTap: busy ? null : () => onReplace(backup),
              )
            : JourneyCell(
                label: TaxiWaysStrings.changeDriver,
                icon: Icons.swap_horiz_rounded,
                onTap: busy || !change ? null : onChangeDriver,
              ),
      ];
    } else {
      cells = [
        callCell,
        change ? JourneyCell(label: TaxiWaysStrings.changeDriver, icon: Icons.swap_horiz_rounded, onTap: busy ? null : onChangeDriver) : null,
      ];
    }
    final plate = d.plateDisplay;
    final vehicle = [
      if (d.vehicleTypeName.isNotEmpty) d.vehicleTypeName,
      if (d.seats != null) JourneyStrings.seatsLabel(d.seats!),
    ].join(' · ');
    return JourneyCard3D(
      tone: toneOf(leg),
      art: JourneyArt.forVehicle(d.vehicleTypeName, d.seats),
      tag: legCount > 0 ? TaxiWaysStrings.carOf(leg.legIndex, legCount) : null,
      title: d.driverName,
      subtitle: [if (vehicle.isNotEmpty) vehicle, if (plate.isNotEmpty) plate],
      pill: JourneyPill3D(label: pillText, ink: pillInk),
      fare: fare == null ? null : BrowseItem.inr(fare),
      note: note,
      noteLines: 2,
      cells: cells,
      semanticsLabel: '${d.driverName}, ${JourneyFormat.driverLine(d)}',
      linkAbove: JourneyInk.lineFor(toneOf(leg)),
    );
  }
}
