import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/service_package_model.dart';
import 'inclusion_chip.dart';
import 'service_package_price.dart';

/// Shared package/plan card — used on Service Detail to render every
/// available package inline, each with its own Enquire/Get Quote button.
/// Replaces the old screen-private `_PackageCard` (service_package_list_screen.dart,
/// now deleted) and `_PackagePreviewCard` (service_detail_screen.dart), fixing
/// their inconsistencies: the media block is always present (never
/// conditionally absent), the title is bounded to 2 lines, and a featured
/// package gets a real visual treatment (accent border + overlay badge)
/// instead of a small pill squeezed next to the title.
class ServicePackageCard extends StatelessWidget {
  final ServicePackageModel package;
  final VoidCallback onEnquire;
  final IconData placeholderIcon;

  const ServicePackageCard({
    super.key,
    required this.package,
    required this.onEnquire,
    required this.placeholderIcon,
  });

  @override
  Widget build(BuildContext context) {
    String? duration;
    if (package.durationDays != null) {
      duration = (package.durationNights != null)
          ? '${package.durationDays}D/${package.durationNights}N'
          : '${package.durationDays} day${package.durationDays == 1 ? '' : 's'}';
    }

    final featured = package.isFeatured;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: featured ? AppColors.primary : AppColors.divider.withValues(alpha: 0.8),
          width: featured ? 1.8 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: package.thumbnailUrl.isEmpty
                      ? _mediaPlaceholder()
                      : CachedNetworkImage(
                          imageUrl: package.thumbnailUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: AppColors.surface),
                          errorWidget: (_, __, ___) => _mediaPlaceholder(),
                        ),
                ),
              ),
              if (featured)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                    child: const Text(
                      'POPULAR',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  package.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                if (duration != null) ...[
                  const SizedBox(height: 4),
                  Text(duration, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w500)),
                ],
                const SizedBox(height: 10),
                ServicePackagePrice(
                  price: package.price,
                  originalPrice: package.originalPrice,
                  discountPercent: package.discountPercent,
                  isStartingAtPrice: package.isStartingAtPrice,
                  priceUnit: package.priceUnit,
                ),
                if (package.inclusions.any((i) => i.isActive)) ...[
                  const SizedBox(height: 12),
                  Text(
                    "What's Included",
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textLight.withValues(alpha: 0.9), letterSpacing: 0.3),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: package.inclusions
                        .where((i) => i.isActive)
                        .map((i) => InclusionChip(iconName: i.iconName, label: i.name))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onEnquire,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      package.price == null ? 'Get Quote' : 'Enquire Now',
                      style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mediaPlaceholder() => Container(
        color: AppColors.primaryLight.withValues(alpha: 0.15),
        child: Center(child: Icon(placeholderIcon, size: 40, color: AppColors.primaryLight)),
      );
}
