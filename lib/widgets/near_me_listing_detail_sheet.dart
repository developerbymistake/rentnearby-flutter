import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../config/app_insets.dart';
import '../config/app_routes.dart';
import '../models/listing_model.dart';

/// Detail sheet for a "Find Near Me" tour card — a SEPARATE widget from the
/// map-pin's ListingBottomSheet (not reused), so it can be opened as a plain
/// overlay without disturbing the tour underneath. Deliberately mirrors that
/// real sheet's structure (drag handle, photo + Available badge, type+price
/// row, furnished chip + distance, single View Details button) so it doesn't
/// feel like a different, unfamiliar component.
class NearMeListingDetailSheet extends StatelessWidget {
  final NearMeListingModel listing;
  const NearMeListingDetailSheet({super.key, required this.listing});

  static IconData _roomTypeIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'pg': return Icons.people_alt_rounded;
      case 'hostel': return Icons.hotel_rounded;
      case '1rk': return Icons.single_bed_rounded;
      default: return Icons.apartment_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: listing.thumbnailUrl != null
                        ? CachedNetworkImage(
                            imageUrl: listing.thumbnailUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: AppColors.surface),
                            errorWidget: (context, url, error) => _photoPlaceholder(),
                          )
                        : _photoPlaceholder(),
                  ),
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: listing.isActive
                            ? AppColors.success.withValues(alpha: 0.92)
                            : AppColors.error.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          listing.isActive ? 'Available' : 'Not Available',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + AppInsets.bottomViewPadding(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(_roomTypeIcon(listing.roomTypeName), size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        listing.roomTypeName ?? 'Room',
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark),
                      ),
                    ),
                    if (listing.priceMonthly != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          listing.shortPrice,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(children: [
                  if (listing.furnishedStatus != 'None')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Iconsax.home_hashtag, size: 13, color: Color(0xFF8B5CF6)),
                        const SizedBox(width: 5),
                        Text(
                          '${listing.furnishedStatus} Furnished',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF8B5CF6)),
                        ),
                      ]),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.textHint.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Iconsax.home_hashtag, size: 13, color: AppColors.textHint),
                        const SizedBox(width: 5),
                        const Text(
                          'Unfurnished',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textHint),
                        ),
                      ]),
                    ),
                  const Spacer(),
                  const Icon(Iconsax.location, size: 13, color: AppColors.textHint),
                  const SizedBox(width: 4),
                  Text(
                    '${listing.distanceKm.toStringAsFixed(1)} km away',
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                  ),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Get.toNamed(AppRoutes.listingDetail, arguments: {'id': listing.id, 'distanceKm': listing.distanceKm});
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('View Details',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
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

  static Widget _photoPlaceholder() => Container(
        color: AppColors.surface,
        child: const Center(
          child: Icon(Icons.home_rounded, size: 56, color: AppColors.primaryLight),
        ),
      );
}
