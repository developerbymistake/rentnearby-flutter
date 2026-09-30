import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';

class DetailTitleRow extends StatelessWidget {
  final Color accent;
  final String tag;
  final IconData icon;
  final String title;
  final String caption;
  final String value;
  final String unit;

  const DetailTitleRow({
    super.key,
    required this.accent,
    required this.tag,
    required this.icon,
    required this.title,
    required this.caption,
    required this.value,
    this.unit = '',
  });

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(6)),
            child: Text(tag,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Colors.white)),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Icon(icon, size: 22, color: accent),
            const SizedBox(width: 8),
            Flexible(
              child: Text(title,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark)),
            ),
          ]),
        ]),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(caption,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textLight)),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: value),
            if (unit.isNotEmpty) TextSpan(text: unit, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.gold, height: 1.2),
        ),
      ]),
    ]);
  }
}

class DetailChipRow extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String label;
  final double? distanceKm;

  const DetailChipRow({super.key, required this.accent, required this.icon, required this.label, this.distanceKm});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: accent)),
        ]),
      ),
      const Spacer(),
      if (distanceKm != null) ...[
        const Icon(Iconsax.location, size: 13, color: AppColors.textHint),
        const SizedBox(width: 4),
        Text('${distanceKm!.toStringAsFixed(1)} km away',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight)),
      ],
    ]);
  }
}
