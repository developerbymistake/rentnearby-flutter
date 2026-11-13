import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../widgets/trip_pace_sheet.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_constants.dart';
import '../trip_strings_v2_plan.dart';
import '../utils/trip_days_rules.dart';

class TripEditSpotSheet extends StatelessWidget {
  final String spotId;

  const TripEditSpotSheet(this.spotId, {super.key});

  static Future<void> show(BuildContext context, String spotId) async {
    final c = TripPlanController.to;
    if (c.isReadOnly) return;
    await SheetFrame.show<void>(context, builder: (_) => TripEditSpotSheet(spotId));
  }

  @override
  Widget build(BuildContext context) {
    final c = TripPlanController.to;
    final plan = c.plan.value;
    final spot = plan?.spotById(spotId);
    final currentDay = plan?.dayOfSpot(spotId);
    if (plan == null || spot == null || currentDay == null) return const SizedBox.shrink();
    final rows = <Widget>[
      for (final d in plan.daysOf(plan.legIndexOf(currentDay)))
        _dayOption(
          context,
          day: d.day,
          current: d.day == currentDay,
          count: d.spots.length,
          onTap: () {
            if (d.day == currentDay) {
              Navigator.pop(context);
              return;
            }
            if (!TripDaysRules.canAddOnDay(plan, d.day)) return;
            Navigator.pop(context);
            c.moveSpot(spotId, d.day, keepEmptyDays: true);
          },
        ),
    ];
    return SheetFrame(
      tone: ListingTone.indigo,
      art: ListingArt.calendar,
      size: SheetSize.confirm,
      title: TripStringsV2Plan.moveTitle(spot.name),
      footer: GradientPillButton(
        tone: ListingTone.indigo,
        label: TripStringsV2Plan.removeFromTrip,
        danger: true,
        onTap: () {
          Navigator.pop(context);
          c.removeSpot(spotId, keepEmptyDays: true);
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) TemplateEntranceOnce(index: i, count: rows.length > 10 ? 10 : rows.length, child: rows[i]),
        ],
      ),
    );
  }

  Widget _dayOption(
    BuildContext context, {
    required int day,
    required bool current,
    required int count,
    required VoidCallback onTap,
  }) {
    final full = !current && count >= TripConstants.maxSpotsPerDay;
    return TripChoiceCard(
      art: ListingArt.calendar,
      label: 'Day $day',
      hint: full ? TripStringsV2Plan.dayIsFull : TripStringsV2Plan.placesCount(count),
      selected: current,
      onTap: full ? null : onTap,
      labelDot: TripKit.dayColor(day),
      trailing: current
          ? Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: DesignColors.surface, borderRadius: BorderRadius.circular(9)),
              child: Icon(Icons.check_rounded, size: 18, color: ListingTone.indigo.text),
            )
          : const SizedBox.shrink(),
    );
  }
}
