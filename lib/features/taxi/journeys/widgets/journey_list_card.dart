import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../../trip/trip_colors.dart';
import '../../../trip/trip_strings_steps_a3.dart';
import '../../taxi_option_sets.dart';
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

  ButtonStyle get _filled => FilledButton.styleFrom(
        minimumSize: const Size(0, 44),
        backgroundColor: TaxiColors.accentDark,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      );

  ButtonStyle get _outlined => OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        foregroundColor: TaxiColors.accentDark,
        side: const BorderSide(color: AppColors.divider),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      );

  Widget _text(String s) => Text(s, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis);

  Widget _actions() {
    final j = journey;
    final open = OutlinedButton(style: _outlined, onPressed: onOpen, child: _text(TaxiWaysStrings.open));
    if (j.isCompleted) return const SizedBox.shrink();
    if (j.status == JourneyStatus.driverUnavailable) {
      final leg = j.firstUnavailable;
      final backup = leg?.readyBackup;
      if (leg != null && backup != null) {
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: _filled,
            onPressed: busy ? null : () => onReplace(leg, backup),
            child: _text(TaxiWaysStrings.replaceWith(backup.driverName)),
          ),
        );
      }
      return SizedBox(width: double.infinity, child: open);
    }
    if (j.status == JourneyStatus.notAsked) {
      return Row(children: [
        Expanded(child: open),
        const SizedBox(width: 8),
        Expanded(child: FilledButton(style: _filled, onPressed: onAsk, child: _text(TaxiWaysStrings.askDrivers))),
      ]);
    }
    return SizedBox(width: double.infinity, child: open);
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
    final actions = _actions();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: j.hasUnavailable && !j.isCompleted ? AppColors.warning : AppColors.divider),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: LayoutBuilder(builder: (context, c) {
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        JourneyFormat.route(j),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        JourneyFormat.line(j),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                      ),
                      if (j.tripId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: TripColors.surface, borderRadius: BorderRadius.circular(999)),
                            child: const Text(
                              TripStringsStepsA3.inYourTrip,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: TripColors.accentDark),
                            ),
                          ),
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
                  Text(note, style: const TextStyle(fontSize: 12, height: 1.35, color: AppColors.textLight)),
                ],
                if (j.isCompleted) const SizedBox.shrink() else ...[
                  const SizedBox(height: 12),
                  actions,
                ],
              ]);
            }),
          ),
        ),
      ),
    );
  }
}
