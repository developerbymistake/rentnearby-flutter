import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/tour_registry.dart';

/// Shared centered dialog for a tour's intro ("Welcome") and outro ("You're
/// all set") checkpoints — one widget, not two, since they differ only in
/// copy and button count (outro has no secondary button). Rendered directly
/// inside TourHost's Obx, NOT via showDialog/Navigator: TourDismissObserver
/// dismisses the tour on any root-Navigator push, so a real Dialog would
/// self-destruct the instant it opened.
class TourInfoDialog extends StatelessWidget {
  final TourDialogContent content;
  final VoidCallback onPrimary;
  final VoidCallback? onSecondary;

  const TourInfoDialog({
    super.key,
    required this.content,
    required this.onPrimary,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final isIntro = content.phase == TourDialogPhase.intro;

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Container(
          // Same scrim color _SpotlightPainter paints, so intro/spotlight/
          // outro read as one visual system.
          color: const Color(0xCC0A0F1E),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: isIntro ? AppColors.primaryGradient : null,
                    color: isIntro ? null : AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isIntro ? '🧭' : '🎉',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  content.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  content.body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMedium,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 20),
                // Stacked, full-width — matches the mock exactly (both
                // buttons width:100%, primary on top). Outro (no
                // secondaryLabel) goes through the same structure rather
                // than a phase-conditional branch — it just degenerates to
                // one full-width button.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: onPrimary,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        // minimumSize/tapTargetSize still needed here even
                        // though the Column now stretches this button to
                        // full width — they only govern HEIGHT, still
                        // overriding app_theme.dart's global
                        // elevatedButtonTheme default (Size(double.infinity,
                        // 54)) that already broke TourOverlay's own Next
                        // button once when left implicit.
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        content.primaryLabel,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (content.secondaryLabel != null) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: onSecondary,
                        child: Text(
                          content.secondaryLabel!,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
