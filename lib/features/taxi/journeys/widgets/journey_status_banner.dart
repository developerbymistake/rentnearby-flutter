import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
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
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: DesignColors.surface,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16)),
        boxShadow: TripKit.shadow(),
      ),
      child: Row(children: [
        const Icon(Icons.wifi_off_rounded, size: 16, color: TripLook.warning),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            TaxiWaysStrings.offlineSaved,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TripKit.text(12, weight: FontWeight.w600, color: DesignColors.textPrimary),
          ),
        ),
      ]),
    );
  }
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
    return Container(
      decoration: journeyBarCard(TripLook.warning),
      child: ClipRRect(
        borderRadius: TripLook.softRadius,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(border: Border(left: BorderSide(color: TripLook.warning, width: 4))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, size: 20, color: TripLook.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(TaxiWaysStrings.statusUnavailable(journey.unavailableCount),
                      style: FitnessAppTheme.title.copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(body, style: FitnessAppTheme.caption.copyWith(height: 1.35)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: backup == null
                  ? JourneyButton(
                      label: TaxiWaysStrings.changeDriver,
                      kind: JourneyButtonKind.outline,
                      onPressed: busy ? null : () => onChange(leg),
                    )
                  : JourneyButton(
                      label: TaxiWaysStrings.replaceWith(backup.driverName),
                      maxLines: 2,
                      onPressed: busy ? null : () => onReplace(leg, backup),
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
