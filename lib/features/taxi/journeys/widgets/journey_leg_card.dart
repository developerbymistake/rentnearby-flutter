import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
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

  const JourneyLegCard({
    super.key,
    required this.leg,
    this.people = 0,
    required this.color,
    required this.busy,
    required this.canChange,
    required this.onChangeDriver,
    required this.onReplace,
  });

  (Color, Color) _statusColors() => switch (leg.lastKnownStatus) {
        LegStatus.free => (TripLook.successText, TripLook.successSurface),
        LegStatus.notFree => (TripLook.errorText, TripLook.errorSurface),
        LegStatus.noAnswer => (DesignColors.textPrimary, TripLook.warningSurface),
        LegStatus.unknown => (TripLook.neutralChipText, TripLook.neutralChip),
      };

  Widget _pill(String text, Color fg, Color bg) => JourneyPill(text: text, fg: fg, bg: bg, fontSize: 11);

  @override
  Widget build(BuildContext context) {
    final d = leg.driver;
    final booked = leg.isBooked;
    final unavailable = !leg.driverAvailable && !booked;
    final change = canChange && !booked;
    final (statusFg, statusBg) = _statusColors();
    final backup = leg.readyBackup;
    final backupNames = leg.backups.where((b) => b.available).map((b) => b.driverName).toList();
    final fare = leg.listedFare;
    final previous = leg.previousFare;
    final quoted = leg.lastQuotedFare;
    final cars = people > 0 ? leg.carsOf(people) : 1;
    final coverNames = leg.coverDrivers.map((c) => c.driverName).where((n) => n.isNotEmpty).toList();
    final bar = unavailable ? TripLook.warning : color;
    final small = FitnessAppTheme.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, color: DesignColors.textPrimary);

    return Container(
      decoration: journeyBarCard(bar),
      child: ClipRRect(
        borderRadius: TripLook.softRadius,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: bar, width: 4))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unavailable ? DesignColors.textMuted : color,
                  boxShadow: ShadowTokens.elev1,
                ),
                child: Text(d.initial, style: FitnessAppTheme.title.copyWith(fontSize: 15, color: DesignColors.surface)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.driverName,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: FitnessAppTheme.title.copyWith(fontSize: 15)),
                  Text(JourneyFormat.driverLine(d), maxLines: 2, overflow: TextOverflow.ellipsis, style: FitnessAppTheme.caption),
                ]),
              ),
              if (fare != null) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 92),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(BrowseItem.inr(fare),
                        style: TripKit.text(15, weight: FontWeight.w700, color: DesignColors.primary)),
                  ),
                ),
              ],
            ]),
            if (cars > 1) ...[
              const SizedBox(height: 6),
              Text(
                  [
                    leg.seatsNote ?? TripStringsA6.seatsNote(d.seats, cars, people),
                    if (coverNames.isNotEmpty) TripStringsFinalAa.withCars(coverNames),
                  ].join(' · '),
                  style: small),
            ],
            if (previous != null && fare != null && previous != fare) ...[
              const SizedBox(height: 6),
              Text(TaxiWaysStrings.fareChanged(previous, fare), style: small),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (booked)
                leg.isConfirmedByBoth
                    ? _pill(TripStringsMcbA2.confirmedByBoth, TripLook.successText, TripLook.successSurface)
                    : _pill(TripStringsMcbA2.bookedByYou, TripLook.booked, TripLook.bookedSurface)
              else if (unavailable)
                _pill(JourneyStrings.unavailableTag, TripLook.errorText, TripLook.errorSurface)
              else
                _pill(JourneyFormat.statusLine(leg, DateTime.now()), statusFg, statusBg),
              if (booked && leg.agreedFare != null)
                Text(TripStringsFinB1.agreedFare(BrowseItem.inr(leg.agreedFare!)),
                    style: FitnessAppTheme.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, color: DesignColors.textGrey))
              else if (!booked && !unavailable && leg.lastKnownStatus == LegStatus.free && quoted != null)
                Text(JourneyStrings.driverQuote(quoted),
                    style: FitnessAppTheme.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, color: DesignColors.textGrey)),
            ]),
            const SizedBox(height: 10),
            if (unavailable)
              SizedBox(
                width: double.infinity,
                child: backup != null
                    ? JourneyButton(
                        label: TaxiWaysStrings.replaceWith(backup.driverName),
                        maxLines: 2,
                        onPressed: busy ? null : () => onReplace(backup),
                      )
                    : JourneyButton(
                        label: TaxiWaysStrings.changeDriver,
                        kind: JourneyButtonKind.outline,
                        onPressed: busy || !change ? null : onChangeDriver,
                      ),
              )
            else ...[
              Row(children: [
                Expanded(
                  child: JourneyButton(
                    label: TaxiWaysStrings.call,
                    kind: JourneyButtonKind.outline,
                    icon: const Icon(Icons.call_rounded, size: 18, color: DesignColors.primary),
                    onPressed: d.hasPhone ? () => ContactLauncher.call(d.phone!) : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: JourneyButton(
                    label: TaxiWaysStrings.whatsApp,
                    kind: JourneyButtonKind.outline,
                    icon: const TravelIcon(TravelIcon.chat, size: 18),
                    onPressed: d.hasWhatsApp ? () => ContactLauncher.whatsApp(d.whatsApp!) : null,
                  ),
                ),
              ]),
              if (!d.hasPhone && !d.hasWhatsApp)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(JourneyStrings.noNumber,
                      style: FitnessAppTheme.caption.copyWith(fontSize: 11, color: DesignColors.textMuted)),
                ),
            ],
            if (!booked && (backupNames.isNotEmpty || (change && !unavailable)))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(spacing: 8, runSpacing: 0, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (backupNames.isNotEmpty)
                    Text(TaxiWaysStrings.backup(backupNames), style: FitnessAppTheme.caption.copyWith(fontSize: 11)),
                  if (change && !unavailable)
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: DesignColors.primary,
                        textStyle: TripKit.text(12, weight: FontWeight.w700),
                      ),
                      onPressed: busy ? null : onChangeDriver,
                      child: const Text(TaxiWaysStrings.changeDriver),
                    ),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}
