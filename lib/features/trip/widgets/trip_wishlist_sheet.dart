import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../controllers/trip_plan_controller.dart';
import '../trip_strings_wizard.dart';
import '../utils/trip_wizard_rules.dart';
import 'trip_sheet_frame.dart';
import 'trip_step_dot.dart';

class TripWishlistSheet {
  static Future<void> show(BuildContext context, {required ValueChanged<String> onPick}) async {
    final steps = TripWizardRules.wishlist(TripPlanController.to.wizardSteps);
    final picked = await TripSheetFrame.show<String>(
      context,
      Builder(
        builder: (sheetCtx) => TripSheetFrame(
          title: TripStringsWizard.wishlistTitle,
          description: steps.isEmpty ? TripStringsWizard.wishlistEmpty : TripStringsWizard.wishlistHint(steps.length),
          children: [
            for (final s in steps) _row(sheetCtx, s),
          ],
        ),
      ),
    );
    if (picked != null) onPick(picked);
  }

  static Widget _row(BuildContext ctx, TripStepInfo s) {
    final mark = TripStepMark.of(s.state);
    return InkWell(
      onTap: () => Navigator.pop(ctx, s.key.id),
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              mark.badge(size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                    Text(s.line,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: mark.text)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}
