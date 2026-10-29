import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_insets.dart';
import '../../../config/app_routes.dart';
import '../../../config/app_shadows.dart';
import '../../../models/browse_item.dart';
import '../../../widgets/detail_header.dart';
import '../setup/stay_option_sets.dart';
import '../models/stay_nearby_model.dart';


class StayBottomSheet extends StatelessWidget {
  final StayNearbyModel stay;
  const StayBottomSheet({super.key, required this.stay});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppShadows.premium(StayColors.accent, alpha: 0.28, blur: 20, offset: const Offset(0, -6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: stay.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: stay.thumbnailUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: AppColors.shimmerBase),
                        errorWidget: (context, url, error) => _photoPlaceholder(),
                      )
                    : _photoPlaceholder(),
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
                  children: [
                    const Icon(Iconsax.building_4, size: 20, color: StayColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Text(
                        stay.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark),
                      ),
                    ),
                    if (stay.minPricePerNight != null) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(gradient: StayColors.gradient, borderRadius: BorderRadius.circular(10)),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'From ${BrowseItem.inr(stay.minPricePerNight!)}/night',
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                  fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                if (stay.stayTypeName != null && stay.stayTypeName!.isNotEmpty)
                  DetailChipRow(
                    accent: StayColors.accent,
                    icon: Iconsax.building_4,
                    label: stay.stayTypeName!,
                    distanceKm: stay.distanceKm,
                  )
                else
                  Row(children: [
                    const Icon(Iconsax.location, size: 13, color: AppColors.textHint),
                    const SizedBox(width: 4),
                    Text(
                      '${stay.distanceKm.toStringAsFixed(1)} km away',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppColors.textLight),
                    ),
                  ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Get.toNamed(AppRoutes.stayDetail, arguments: {'id': stay.id, 'distanceKm': stay.distanceKm});
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('View Details',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: StayColors.accent,
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
        color: AppColors.shimmerBase,
        child: const Center(child: Icon(Iconsax.building_4, size: 56, color: StayColors.accent)),
      );
}
