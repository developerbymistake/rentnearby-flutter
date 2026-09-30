import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../config/app_shadows.dart';

class NearbyItemRow extends StatelessWidget {
  final String? thumbnailUrl;
  final String tag;
  final String title;
  final String subtitle;
  final String caption;
  final String value;
  final String unit;
  final bool isPlot;
  final IconData placeholderIcon;
  final bool elevated;
  final VoidCallback onTap;

  const NearbyItemRow({
    super.key,
    required this.thumbnailUrl,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.caption,
    required this.value,
    this.unit = '',
    required this.isPlot,
    required this.placeholderIcon,
    required this.onTap,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentFor(isPlot);
    final size = elevated ? 64.0 : 54.0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: elevated ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        padding: EdgeInsets.symmetric(horizontal: elevated ? 10 : 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
          boxShadow: elevated
              ? AppShadows.premium(accent, alpha: 0.14, blur: 18, offset: const Offset(0, 6))
              : AppShadows.premium(accent, alpha: 0.06, blur: 10, offset: const Offset(0, 3)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: size,
                height: size,
                child: (thumbnailUrl == null || thumbnailUrl!.isEmpty)
                    ? _placeholder(accent)
                    : CachedNetworkImage(
                        imageUrl: thumbnailUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppColors.surfaceWarm),
                        errorWidget: (_, __, ___) => _placeholder(accent),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(5)),
                    child: Text(tag,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Colors.white)),
                  ),
                  const SizedBox(height: 4),
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const SizedBox(height: 1),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(caption,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textLight)),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: value),
                    if (unit.isNotEmpty) TextSpan(text: unit, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                  ]),
                  maxLines: 1,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.gold),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Iconsax.arrow_right_3, size: 16, color: accent),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(Color accent) => Container(
        decoration: BoxDecoration(gradient: AppColors.gradientFor(isPlot)),
        child: Center(child: Icon(placeholderIcon, size: 22, color: Colors.white70)),
      );
}
