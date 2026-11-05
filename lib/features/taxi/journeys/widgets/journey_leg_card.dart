import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../../../models/browse_item.dart';
import '../../../../utils/contact_launcher.dart';
import '../../../trip/trip_colors.dart';
import '../../../trip/trip_strings_fin_b1.dart';
import '../../../trip/trip_strings_final_aa.dart';
import '../../taxi_option_sets.dart';
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

  ButtonStyle _outlined(Color fg) => OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: fg,
        side: const BorderSide(color: AppColors.divider),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      );

  Widget _label(String s) => FittedBox(fit: BoxFit.scaleDown, child: Text(s, maxLines: 1));

  (Color, Color) _statusColors() => switch (leg.lastKnownStatus) {
        LegStatus.free => (TripStatusColors.both, TripStatusColors.bothSurface),
        LegStatus.notFree => (TripStatusColors.failed, TripStatusColors.failedSurface),
        LegStatus.noAnswer => (TripStatusColors.waiting, TripStatusColors.waitingSurface),
        LegStatus.unknown => (AppColors.neutralChipText, AppColors.neutralChip),
      };

  Widget _pill(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
      );

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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(width: 5, color: unavailable ? AppColors.warning : color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: unavailable ? AppColors.textHint : color),
                      child: Text(d.initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d.driverName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                        Text(JourneyFormat.driverLine(d),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                      ]),
                    ),
                    if (fare != null) ...[
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 92),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(BrowseItem.inr(fare),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.warningText)),
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
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.warningText)),
                  ],
                  if (previous != null && fare != null && previous != fare) ...[
                    const SizedBox(height: 6),
                    Text(TaxiWaysStrings.fareChanged(previous, fare),
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.warningText)),
                  ],
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    if (booked)
                      leg.isConfirmedByBoth
                          ? _pill(TripStringsMcbA2.confirmedByBoth, TripStatusColors.both, TripStatusColors.bothSurface)
                          : _pill(TripStringsMcbA2.bookedByYou, TripStatusColors.booked, TripStatusColors.bookedSurface)
                    else if (unavailable)
                      _pill(JourneyStrings.unavailableTag, AppColors.errorText, AppColors.errorSurface)
                    else
                      _pill(JourneyFormat.statusLine(leg, DateTime.now()), statusFg, statusBg),
                    if (booked && leg.agreedFare != null)
                      Text(TripStringsFinB1.agreedFare(BrowseItem.inr(leg.agreedFare!)),
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMedium))
                    else if (!booked && !unavailable && leg.lastKnownStatus == LegStatus.free && quoted != null)
                      Text(JourneyStrings.driverQuote(quoted),
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMedium)),
                  ]),
                  const SizedBox(height: 10),
                  if (unavailable)
                    SizedBox(
                      width: double.infinity,
                      child: backup != null
                          ? FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                backgroundColor: TaxiColors.accentDark,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: busy ? null : () => onReplace(backup),
                              child: Text(TaxiWaysStrings.replaceWith(backup.driverName),
                                  maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                            )
                          : OutlinedButton(
                              style: _outlined(TaxiColors.accentDark),
                              onPressed: busy || !change ? null : onChangeDriver,
                              child: _label(TaxiWaysStrings.changeDriver),
                            ),
                    )
                  else ...[
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: _outlined(TaxiColors.accentDark),
                          onPressed: d.hasPhone ? () => ContactLauncher.call(d.phone!) : null,
                          icon: const Icon(Icons.call_rounded, size: 18),
                          label: _label(TaxiWaysStrings.call),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: _outlined(AppColors.successDark),
                          onPressed: d.hasWhatsApp ? () => ContactLauncher.whatsApp(d.whatsApp!) : null,
                          icon: const Icon(Icons.chat_rounded, size: 18),
                          label: _label(TaxiWaysStrings.whatsApp),
                        ),
                      ),
                    ]),
                    if (!d.hasPhone && !d.hasWhatsApp)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(JourneyStrings.noNumber, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                      ),
                  ],
                  if (!booked && (backupNames.isNotEmpty || (change && !unavailable)))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(spacing: 8, runSpacing: 0, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        if (backupNames.isNotEmpty)
                          Text(TaxiWaysStrings.backup(backupNames),
                              style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                        if (change && !unavailable)
                          TextButton(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              foregroundColor: TaxiColors.accentDark,
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            onPressed: busy ? null : onChangeDriver,
                            child: const Text(TaxiWaysStrings.changeDriver),
                          ),
                      ]),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
