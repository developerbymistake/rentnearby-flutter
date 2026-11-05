import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../models/trip_plan_model.dart';
import '../trip_colors.dart';

class TripStepLook {
  final Color dot;
  final Color surface;
  final Color text;
  final IconData? icon;

  const TripStepLook(this.dot, this.surface, this.text, this.icon);

  static TripStepLook of(TripStepDisplay display, {bool attention = false}) {
    if (attention) {
      return const TripStepLook(TripStatusColors.waiting, AppColors.warningSurface, AppColors.warningText, Icons.priority_high_rounded);
    }
    return switch (display) {
      TripStepDisplay.notStarted => const TripStepLook(AppColors.textHint, AppColors.neutralChip, AppColors.neutralChipText, null),
      TripStepDisplay.asked =>
        const TripStepLook(TripStatusColors.waiting, AppColors.warningSurface, AppColors.warningText, Icons.more_horiz_rounded),
      TripStepDisplay.chosen => const TripStepLook(AppColors.success, AppColors.successSurface, AppColors.successText, Icons.check_rounded),
      TripStepDisplay.booked ||
      TripStepDisplay.own =>
        const TripStepLook(TripStatusColors.booked, TripStatusColors.bookedSurface, TripStatusColors.booked, Icons.check_rounded),
      TripStepDisplay.skipped =>
        const TripStepLook(AppColors.textLight, AppColors.neutralChip, AppColors.neutralChipText, Icons.remove_rounded),
      TripStepDisplay.notNeeded =>
        const TripStepLook(AppColors.textLight, AppColors.neutralChip, AppColors.neutralChipText, Icons.check_rounded),
    };
  }
}

class TripStepDot extends StatelessWidget {
  final TripStepDisplay display;
  final bool attention;
  final double size;

  const TripStepDot(this.display, {super.key, this.attention = false, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final look = TripStepLook.of(display, attention: attention);
    final empty = look.icon == null;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: empty ? look.dot.withValues(alpha: 0.45) : look.dot,
      ),
      child: empty ? null : Icon(look.icon, size: size * 0.66, color: Colors.white),
    );
  }
}
