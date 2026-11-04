import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../setup/stay_option_sets.dart';

enum StayEnquiryButtonKind { primary, positive, negative, plain }

class StayEnquiryButton extends StatelessWidget {
  const StayEnquiryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = StayEnquiryButtonKind.plain,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final StayEnquiryButtonKind kind;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color border) = switch (kind) {
      StayEnquiryButtonKind.primary => (StayColors.accent, Colors.white, StayColors.accent),
      StayEnquiryButtonKind.positive => (AppColors.success, Colors.white, AppColors.success),
      StayEnquiryButtonKind.negative => (Colors.white, AppColors.error, AppColors.error),
      StayEnquiryButtonKind.plain => (Colors.white, StayColors.accentDark, AppColors.divider),
    };
    final enabled = onTap != null && !busy;
    return Opacity(
      opacity: onTap == null && !busy ? 0.5 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              if (busy)
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
              else ...[
                if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
