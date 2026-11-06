import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../taxi/ways/trip_strings_journey_card.dart';
import '../controllers/trip_plan_controller.dart';
import '../models/trip_plan_model.dart';
import '../screens/trip_details_sheet.dart';
import '../trip_colors.dart';
import '../utils/trip_wizard_rules.dart';
import 'trip_going_home_row.dart';
import 'trip_journey_card.dart';

class TripJourneyStepBody extends StatelessWidget {
  const TripJourneyStepBody({super.key, this.role, this.legIndex, this.state, this.extra})
      : assert((role == null) != (legIndex == null));

  final TripStepRole? role;
  final int? legIndex;
  final Widget? state;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    return Obx(() {
      final p = c.plan.value;
      c.trip.value;
      if (p == null) return const SizedBox.shrink();
      final start = _start(c);
      final noDates = c.settings.startDate == null;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        _startCard(start.heading, start.line),
        const SizedBox(height: 16),
        Text(
          _question(c),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textDark),
        ),
        const SizedBox(height: 12),
        if (state != null) ...[state!, const SizedBox(height: 14)],
        if (extra != null) ...[extra!, const SizedBox(height: 14)],
        if (noDates && !c.isReadOnly) ...[
          _addDates(context),
          const SizedBox(height: 12),
        ],
        TripJourneyCard(role: role, legIndex: legIndex),
      ]);
    });
  }

  ({String heading, String line}) _start(TripPlanController c) {
    final k = legIndex;
    if (k != null) {
      final p = c.plan.value;
      final prev = p?.legAt(k - 1)?.cityName ?? '';
      final night = (p?.legStart(k) ?? 0) - 1;
      final s = night >= 1 && p?.legIndexOf(night) == k - 1 ? c.nightStart(night) : null;
      if (s == null || s.kind == TripStartKind.notChosen) {
        return (heading: TripStringsJourneyCard.startsFrom, line: TripStringsJourneyCard.fromPlace(prev));
      }
      return (heading: s.heading, line: s.line);
    }
    if (role == TripStepRole.comingBack) {
      final s = c.comingBackStart;
      return (heading: s.heading, line: s.line);
    }
    final from = c.startFrom?.name;
    return (
      heading: TripStringsJourneyCard.startsFrom,
      line: from == null ? TripStringsJourneyCard.startNotSet : TripStringsJourneyCard.fromPlace(from),
    );
  }

  String _question(TripPlanController c) {
    final k = legIndex;
    if (k != null) return TripStringsJourneyCard.goTo(c.plan.value?.legAt(k)?.cityName ?? '');
    if (role == TripStepRole.gettingThere) return TripStringsJourneyCard.reachCity(c.cityName);
    return TripStringsJourneyCard.getBackTo(c.homeEndName);
  }

  Widget _startCard(String heading, String line) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: TripColors.surface, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Iconsax.location, size: 18, color: TripColors.accentDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(heading,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: AppColors.warningText)),
              Text(line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            ]),
          ),
        ]),
      );

  Widget _addDates(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        decoration: BoxDecoration(color: AppColors.warningSurface, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Iconsax.calendar_1, size: 18, color: AppColors.warningText),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(TripStringsJourneyCard.addDatesToAsk,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.warningText)),
              Text(TripStringsJourneyCard.addDatesBody,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.warningText)),
            ]),
          ),
          TextButton(
            onPressed: () => TripDetailsSheet.edit(context, heading: TripStringsJourneyCard.addDatesToAsk),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 10)),
            child: const Text(TripStringsJourneyCard.addDates,
                maxLines: 1,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.warningText)),
          ),
        ]),
      );
}
