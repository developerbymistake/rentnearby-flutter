import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import '../../ways/taxi_ways_strings.dart';
import '../journey_models.dart';

class JourneyStatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const JourneyStatusPill({super.key, required this.text, required this.color, required this.background});

  factory JourneyStatusPill.of(SavedJourney j) {
    final (fg, bg) = switch (j.status) {
      JourneyStatus.ready => (TripLook.successText, TripLook.successSurface),
      JourneyStatus.driverUnavailable => (DesignColors.textPrimary, TripLook.warningSurface),
      JourneyStatus.notAsked => (TripLook.neutralChipText, TripLook.neutralChip),
      JourneyStatus.completed => (TripLook.neutralChipText, TripLook.neutralChip),
    };
    return JourneyStatusPill(text: JourneyFormat.statusText(j), color: fg, background: bg);
  }

  @override
  Widget build(BuildContext context) => JourneyPill(text: text, fg: color, bg: background);
}

class JourneyOfflineBanner extends StatelessWidget {
  const JourneyOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) => const JourneyBanner3D(text: TaxiWaysStrings.offlineSaved, art: ListingArt.worldMap);
}

class JourneyStatusBanner extends StatelessWidget {
  final SavedJourney journey;
  final bool busy;
  final void Function(SavedJourneyLeg leg, JourneyContact backup) onReplace;
  final void Function(SavedJourneyLeg leg) onChange;

  const JourneyStatusBanner({
    super.key,
    required this.journey,
    required this.busy,
    required this.onReplace,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final leg = journey.firstUnavailable;
    if (leg == null) return const SizedBox.shrink();
    final backup = leg.readyBackup;
    final body = backup == null
        ? TaxiWaysStrings.pausedNoBackup(leg.driver.driverName)
        : TaxiWaysStrings.pausedBody(leg.driver.driverName, backup.driverName);
    return JourneyBanner3D(
      error: true,
      art: ListingArt.taxi,
      title: TaxiWaysStrings.statusUnavailable(journey.unavailableCount),
      text: body,
      button: GradientPillButton(
        tone: ListingTone.coral,
        height: 52,
        fontSize: 15,
        label: backup == null ? TaxiWaysStrings.changeDriver : TaxiWaysStrings.replaceWith(backup.driverName),
        loading: busy,
        onTap: busy ? null : (backup == null ? () => onChange(leg) : () => onReplace(leg, backup)),
      ),
    );
  }
}
