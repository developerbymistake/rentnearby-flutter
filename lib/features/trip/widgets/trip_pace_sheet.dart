import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_constants.dart';
import '../trip_strings_v2_plan.dart';

class TripPaceSheet {
  static Future<int?> show(BuildContext context) {
    final current = TripPlanController.to.settings.dayLimitMinutes;
    return SheetFrame.show<int>(
      context,
      builder: (ctx) => SheetFrame(
        title: TripStringsV2Plan.paceTitle,
        subtitle: TripStringsV2Plan.paceSub,
        footer: Text(
          TripStringsV2Plan.paceFooter,
          textAlign: TextAlign.center,
          style: TypeTokens.style(12, FontWeight.w400, color: TypeTokens.secondary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _row(ctx, TripStringsV2Plan.paceRelaxed, TripStringsV2Plan.paceRelaxedHint, TripPace.relaxed,
                current <= TripPace.relaxed),
            const SizedBox(height: 12),
            _row(ctx, TripStringsV2Plan.paceNormal, TripStringsV2Plan.paceNormalHint, TripPace.normal,
                current > TripPace.relaxed),
          ],
        ),
      ),
    );
  }

  static Widget _row(BuildContext ctx, String label, String hint, int minutes, bool selected) {
    return PressScale(
      child: InkWell(
      onTap: () => Navigator.pop(ctx, selected ? null : minutes),
      borderRadius: CardRadius.tile,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? null : DesignColors.surface,
          gradient: selected ? KitTone.trip.gradient : null,
          borderRadius: CardRadius.tile,
          boxShadow: selected ? ShadowTokens.glow(KitTone.trip.glow) : ShadowTokens.elev2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: TypeTokens.style(14, FontWeight.w700,
                          color: selected ? DesignColors.onPrimary : DesignColors.textStrong)),
                  Text(hint,
                      style: TypeTokens.style(12, FontWeight.w600,
                          color: selected ? DesignColors.onPrimary : TypeTokens.secondary)),
                ],
              ),
            ),
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? DesignColors.onPrimary : DesignColors.textMuted),
          ],
        ),
      ),
      ),
    );
  }
}
