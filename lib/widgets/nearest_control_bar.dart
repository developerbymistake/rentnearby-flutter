import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// Prev/Next + dots + Cancel, meant to sit directly above the bottom preview
/// card in nearest-carousel mode. [current]/[total] are display-only —
/// [onPrev]/[onNext] are already index-clamped by the caller.
class NearestControlBar extends StatelessWidget {
  final int current;
  final int total;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onCancel;

  const NearestControlBar({
    super.key,
    required this.current,
    required this.total,
    required this.onPrev,
    required this.onNext,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.chevron_left_rounded,
            label: 'Prev',
            iconLeading: true,
            enabled: current > 0,
            onTap: onPrev,
          ),
          const SizedBox(width: 6),
          _NavButton(
            icon: Icons.chevron_right_rounded,
            label: 'Next',
            iconLeading: false,
            enabled: current < total - 1,
            onTap: onNext,
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(total, (i) {
                  final active = i == current;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: active ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: active ? AppColors.primaryGradient : null,
                      color: active ? null : AppColors.divider,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withValues(alpha: 0.32),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool iconLeading;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.iconLeading,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Colors.white : AppColors.textHint;
    final iconWidget = Icon(icon, size: 18, color: color);
    final textWidget = Text(
      label,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: enabled ? AppColors.primaryGradient : null,
          color: enabled ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(11),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.32),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: iconLeading
              ? [iconWidget, const SizedBox(width: 3), textWidget]
              : [textWidget, const SizedBox(width: 3), iconWidget],
        ),
      ),
    );
  }
}
