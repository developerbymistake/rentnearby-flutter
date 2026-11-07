import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_colors.dart';
import '../trip_constants.dart';
import '../trip_strings_v2_plan.dart';
import 'trip_sheet_frame.dart';

class TripPaceSheet {
  static Future<int?> show(BuildContext context) {
    final current = TripPlanController.to.settings.dayLimitMinutes;
    return TripSheetFrame.show<int>(
      context,
      Builder(
        builder: (ctx) => TripSheetFrame(
          title: TripStringsV2Plan.paceTitle,
          description: TripStringsV2Plan.paceSub,
          footer: const Text(
            TripStringsV2Plan.paceFooter,
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
          ),
          children: [
            _row(ctx, TripStringsV2Plan.paceRelaxed, TripStringsV2Plan.paceRelaxedHint, TripPace.relaxed,
                current <= TripPace.relaxed),
            const SizedBox(height: 8),
            _row(ctx, TripStringsV2Plan.paceNormal, TripStringsV2Plan.paceNormalHint, TripPace.normal,
                current > TripPace.relaxed),
          ],
        ),
      ),
    );
  }

  static Widget _row(BuildContext ctx, String label, String hint, int minutes, bool selected) {
    return InkWell(
      onTap: () => Navigator.pop(ctx, selected ? null : minutes),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? TripColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? TripColors.accent : AppColors.divider, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  Text(hint, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
                ],
              ),
            ),
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? TripColors.accentDark : AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
