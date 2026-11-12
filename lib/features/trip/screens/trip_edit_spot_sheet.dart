import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../widgets/trip_ui.dart';
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
      PressScale(
        child: InkWell(
          borderRadius: CardRadius.chip,
          onTap: () {
            Navigator.pop(context);
            c.removeSpot(spotId, keepEmptyDays: true);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: KitMetrics.touch),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  const Icon(Icons.delete_outline_rounded, size: 18, color: TripUi.bad),
                  const SizedBox(width: 8),
                  Text(TripStringsV2Plan.removeFromTrip, style: TypeTokens.style(14, FontWeight.w600, color: TripUi.bad)),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
    return SheetFrame(
      title: TripStringsV2Plan.moveTitle(spot.name),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TripSurface(
        onTap: full ? null : onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderColor: current ? DesignColors.primary : null,
        shadow: current ? ShadowTokens.elev3 : ShadowTokens.elev1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 24),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: TripKit.dayColor(day), shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                'Day $day',
                style: TextStyle(
                  fontFamily: FitnessAppTheme.fontName,
                  fontSize: 13,
                  fontWeight: current ? FontWeight.w700 : FontWeight.w600,
                  color: full ? DesignColors.textMuted : (current ? FitnessAppTheme.nearlyDarkBlue : FitnessAppTheme.darkerText),
                ),
              ),
              const Spacer(),
              Text(
                full ? TripStringsV2Plan.dayIsFull : TripStringsV2Plan.placesCount(count),
                style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: 12, color: full ? DesignColors.textMuted : FitnessAppTheme.lightText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
