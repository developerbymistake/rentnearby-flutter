import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/service_package_model.dart';
import 'service_package_price.dart';

/// Shared package/plan card — used on Service Detail to render every
/// available package inline, each with its own Enquire/Get Quote button.
/// No media block: no catalog package has a real thumbnail today (every
/// Char Dham/Tour/Yoga package seeds ThumbnailUrl empty), so a "featured"
/// package always shows its POPULAR badge as an inline pill next to the
/// title rather than an overlay on a photo that never exists. Inclusions
/// are Service-scoped, not rendered per-card — see the single block on
/// `service_detail_screen.dart` instead (every package/group-size tier of
/// a Service shares the same inclusion set).
class ServicePackageCard extends StatelessWidget {
  final ServicePackageModel package;
  final VoidCallback onEnquire;

  const ServicePackageCard({
    super.key,
    required this.package,
    required this.onEnquire,
  });

  @override
  Widget build(BuildContext context) {
    final featured = package.isFeatured;
    final duration = package.durationLabel;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: featured ? AppColors.primary : AppColors.divider.withValues(alpha: 0.8),
          width: featured ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  package.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ),
              if (featured) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                    'POPULAR',
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.3),
                  ),
                ),
              ],
              if (duration != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    duration,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ),
              ],
            ],
          ),
          // "Starting at" moves to its own small line here (between the name row above and
          // the price row below) instead of sharing the price row with it — that combined
          // "Starting at ₹X / unit" text was too wide next to the Enquire button, clipping
          // its label. ServicePackagePrice itself is unchanged (shared elsewhere) — just told
          // isStartingAtPrice: false here since this label covers that meaning already.
          if (package.isStartingAtPrice && package.price != null) ...[
            const SizedBox(height: 6),
            const Text(
              'Starting at',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textLight),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: ServicePackagePrice(
                  price: package.price,
                  originalPrice: package.originalPrice,
                  discountPercent: package.discountPercent,
                  isStartingAtPrice: false,
                  priceUnit: package.priceUnit,
                  priceFontSize: 16,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: onEnquire,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  // Overrides the app-wide ElevatedButtonTheme's minimumSize (Size(double.infinity,
                  // 54), see app_theme.dart) — without this, this non-Expanded button next to
                  // Expanded(ServicePackagePrice) in the Row above gets an infinite-width
                  // constraint, which release builds silently fail to paint (no assert, no error
                  // box — the whole Row just renders blank).
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: Text(
                  package.price == null ? 'Get Quote' : 'Enquire Now',
                  style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
