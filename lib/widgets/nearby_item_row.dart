import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';

/// A single row inside the Explore map's "View List" bottom sheet — thumbnail
/// + title/subtitle + a trailing value. Deliberately model-agnostic (plain
/// strings in, not a NearbyListingModel/NearbyPlotModel) so it works for both
/// Rooms (trailing = price) and Plots (trailing = area) without coupling to
/// either model.
class NearbyItemRow extends StatelessWidget {
  final String? thumbnailUrl;
  final String title;
  final String subtitle;
  final String trailingText;
  final Color trailingColor;
  final IconData placeholderIcon;
  final VoidCallback onTap;

  const NearbyItemRow({
    super.key,
    required this.thumbnailUrl,
    required this.title,
    required this.subtitle,
    required this.trailingText,
    required this.trailingColor,
    required this.placeholderIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 54,
                height: 54,
                child: (thumbnailUrl == null || thumbnailUrl!.isEmpty)
                    ? _placeholder()
                    : CachedNetworkImage(
                        imageUrl: thumbnailUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppColors.surface),
                        errorWidget: (_, __, ___) => _placeholder(),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              trailingText,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w800, color: trailingColor),
            ),
            const SizedBox(width: 4),
            const Icon(Iconsax.arrow_right_3, size: 16, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.surface,
        child: Center(child: Icon(placeholderIcon, size: 22, color: AppColors.primaryLight)),
      );
}
