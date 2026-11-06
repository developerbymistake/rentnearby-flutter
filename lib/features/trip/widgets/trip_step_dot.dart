import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../trip_colors.dart';
import '../utils/trip_wizard_rules.dart';

class TripStepMark {
  final Color color;
  final Color surface;
  final Color text;
  final IconData? icon;

  const TripStepMark(this.color, this.surface, this.text, this.icon);

  static TripStepMark of(TripStepState state) => switch (state) {
        TripStepState.todo => const TripStepMark(AppColors.textHint, AppColors.neutralChip, AppColors.neutralChipText, null),
        TripStepState.waiting => const TripStepMark(
            TripStatusColors.waiting, AppColors.warningSurface, AppColors.warningText, Icons.more_horiz_rounded),
        TripStepState.attention => const TripStepMark(
            TripStatusColors.failed, TripStatusColors.failedSurface, AppColors.errorText, Icons.priority_high_rounded),
        TripStepState.done =>
          const TripStepMark(AppColors.success, AppColors.successSurface, AppColors.successText, Icons.check_rounded),
        TripStepState.own =>
          const TripStepMark(AppColors.textLight, AppColors.neutralChip, AppColors.neutralChipText, Icons.check_rounded),
        TripStepState.skipped =>
          const TripStepMark(AppColors.textLight, AppColors.neutralChip, AppColors.neutralChipText, Icons.remove_rounded),
      };

  Widget badge({double size = 32, String? number, bool pop = false, bool reduceMotion = false}) {
    final glyph = icon;
    final empty = glyph == null;
    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: empty ? Colors.white : color,
        border: empty ? Border.all(color: color, width: 1.5) : null,
      ),
      child: Center(
        child: empty
            ? (number == null
                ? null
                : Text(number,
                    maxLines: 1,
                    style: TextStyle(
                        fontFamily: 'Poppins', fontSize: size * 0.4, fontWeight: FontWeight.w700, color: AppColors.textLight)))
            : Icon(glyph, size: size * 0.56, color: Colors.white),
      ),
    );
    if (!pop) return circle;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 1.0 : 0.4, end: 1.0),
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: circle,
    );
  }
}
