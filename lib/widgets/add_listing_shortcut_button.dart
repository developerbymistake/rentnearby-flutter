import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// "Find Nearest" / "Add my room" (or "Add my plot") shortcut — shared by the Rooms and Plots
/// Explore screens so the CTA's color/border/shape stays byte-identical between both tabs (only
/// label/icon/destination/gradient differ per caller). A standalone full pill, icon-then-label
/// always — the caller's Positioned decides where it sits (both explore screens inset it to the
/// same left/right bounds as the filter panel directly below it).
class AddListingShortcutButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  // Defaults to the Room-tab blue gradient so the existing Rooms call site is unaffected — the
  // Plots call site passes AppColors.plotGradient (the same coral/terracotta pair used everywhere
  // else on the Plots tab) instead of inheriting Room's color.
  final Gradient gradient;

  const AddListingShortcutButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.gradient = AppColors.primaryGradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 9, 15, 9),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2.4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
