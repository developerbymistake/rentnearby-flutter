import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// "Add my room" / "Add my plot" shortcut — shared by the Rooms and Plots
/// Explore screens so the CTA's color/border/shape stays byte-identical
/// between both tabs (only label/icon/destination differ per caller). Sits
/// flush against the screen's right edge as an edge tab — rounded on the side
/// facing into the screen, square on the side touching the edge — reads as a
/// handle poking out from the side rather than a free-floating pill.
class AddListingShortcutButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const AddListingShortcutButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 9, 16, 9),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(22),
            bottomLeft: Radius.circular(22),
          ),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.9), width: 3),
            left: BorderSide(color: Colors.white.withValues(alpha: 0.9), width: 3),
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.9), width: 3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(-3, 4),
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
            const SizedBox(width: 5),
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
