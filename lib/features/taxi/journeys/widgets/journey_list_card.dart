import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import '../../../trip/trip_strings_mcb_a3.dart';
import '../../../trip/trip_strings_steps_a3.dart';
import '../../ways/taxi_ways_strings.dart';
import '../journey_models.dart';
import 'journey_status_banner.dart';

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

  Widget _actions() {
    final j = journey;
    final open = JourneyButton(label: TaxiWaysStrings.open, kind: JourneyButtonKind.outline, maxLines: 2, onPressed: onOpen);
    if (j.isCompleted) return const SizedBox.shrink();
    if (j.status == JourneyStatus.driverUnavailable) {
      final leg = j.firstUnavailable;
      final backup = leg?.readyBackup;
      if (leg != null && backup != null) {
        return SizedBox(
          width: double.infinity,
          child: JourneyButton(
            label: TaxiWaysStrings.replaceWith(backup.driverName),
            maxLines: 2,
            onPressed: busy ? null : () => onReplace(leg, backup),
          ),
        );
      }
      return SizedBox(width: double.infinity, child: open);
    }
    if (j.status == JourneyStatus.notAsked) {
      return Row(children: [
        Expanded(child: open),
        const SizedBox(width: 8),
        Expanded(child: JourneyButton(label: TaxiWaysStrings.askDrivers, maxLines: 2, onPressed: onAsk)),
      ]);
    }
    return SizedBox(width: double.infinity, child: open);
  }

  @override
  Widget build(BuildContext context) {
    final j = journey;
    final leg = j.firstUnavailable;
    final warn = j.hasUnavailable && !j.isCompleted;
    final note = j.status == JourneyStatus.driverUnavailable && leg != null
        ? (leg.readyBackup == null
            ? TaxiWaysStrings.pausedNoBackup(leg.driver.driverName)
            : TaxiWaysStrings.pausedBody(leg.driver.driverName, leg.readyBackup!.driverName))
        : null;
    return Container(
      decoration: TripLook.card(shadowColor: warn ? TripLook.warning : null),
      child: ClipRRect(
        borderRadius: TripLook.softRadius,
        child: Material(
          color: DesignColors.surface,
          child: InkWell(
            onTap: onOpen,
            child: Container(
              decoration: warn ? const BoxDecoration(border: Border(left: BorderSide(color: TripLook.warning, width: 4))) : null,
              padding: const EdgeInsets.all(14),
              child: LayoutBuilder(builder: (context, c) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(JourneyFormat.route(j),
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: FitnessAppTheme.title.copyWith(fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(JourneyFormat.line(j), maxLines: 2, overflow: TextOverflow.ellipsis, style: FitnessAppTheme.caption),
                        if (j.tripId != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: JourneyPill(
                                text: _tripChip(j), fg: TripLook.accentDark, bg: TripLook.surface, fontSize: 11, maxLines: 1),
                          ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: c.maxWidth * 0.45),
                      child: JourneyStatusPill.of(j),
                    ),
                  ]),
                  if (note != null) ...[
                    const SizedBox(height: 8),
                    Text(note, style: FitnessAppTheme.caption.copyWith(height: 1.35)),
                  ],
                  if (!j.isCompleted) ...[
                    const SizedBox(height: 12),
                    _actions(),
                  ],
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }
}
