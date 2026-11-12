import 'package:flutter/material.dart';
import '../design/design.dart';

class AddListingShortcutButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Gradient gradient;

  const AddListingShortcutButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.gradient = TripEntryStyle.gradient,
  });

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(38));
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: radius,
        boxShadow: [
          ShadowTokens.tint(FitnessAppTheme.grey, ShadowSpec.elev3Spec),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          splashColor: FitnessAppTheme.white.withValues(alpha: Alpha.soft),
          highlightColor: Colors.transparent,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 9, 15, 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: FitnessAppTheme.nearlyWhite.withValues(alpha: Alpha.soft),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 13, color: FitnessAppTheme.white),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: FitnessAppTheme.body2.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: FitnessAppTheme.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
