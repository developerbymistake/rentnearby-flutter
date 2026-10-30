import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';

class PlanCycleOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? price;
  final String? perMonth;
  final bool best;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final String? unavailableText;
  final VoidCallback? onRetry;

  const PlanCycleOption({
    super.key,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.perMonth,
    required this.best,
    required this.selected,
    required this.onTap,
    required this.accent,
    this.unavailableText,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(clipBehavior: Clip.none, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? accent : AppColors.divider, width: selected ? 1.6 : 1.5),
          ),
          child: Row(children: [
            _radio(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
              ]),
            ),
            const SizedBox(width: 8),
            Flexible(child: _priceColumn()),
          ]),
        ),
        if (best)
          Positioned(
            top: -9,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(color: AppColors.successDark, borderRadius: BorderRadius.circular(999)),
              child: const Text('BEST VALUE',
                  style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
      ]),
    );
  }

  Widget _radio() => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 20,
        height: 20,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: selected ? accent : AppColors.textHint, width: 2),
        ),
        child: selected
            ? Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: accent))
            : null,
      );

  Widget _priceColumn() {
    final unavailable = unavailableText;
    if (unavailable != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
        Text(unavailable,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight)),
        if (onRetry != null)
          GestureDetector(
            onTap: onRetry,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Retry',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: accent)),
            ),
          ),
      ]);
    }
    final p = price;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
      if (p == null)
        Shimmer.fromColors(
          baseColor: AppColors.divider,
          highlightColor: Colors.white,
          child: Container(
            width: 60,
            height: 18,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
          ),
        )
      else
        Text(p,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      if (p != null && perMonth != null && perMonth!.isNotEmpty)
        Text(perMonth!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textLight)),
    ]);
  }
}
