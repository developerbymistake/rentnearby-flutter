import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';

/// ViewAllScreen's grid card — full-bleed photo, price/area scrim overlay,
/// eye icon (view details) and a Chat action. Photo/placeholder handling
/// mirrors home_screen.dart's `_HomeListingCard`, restructured into the
/// grid layout approved in the 39.4/39.8 mockups.
class ListingGridCard extends StatelessWidget {
  final String? thumbnailUrl;
  final String badgeLabel;
  final String priceLabel;
  final String title;
  final String locationLabel;
  final VoidCallback onViewDetails;
  final VoidCallback onChat;

  const ListingGridCard({
    super.key,
    required this.thumbnailUrl,
    required this.badgeLabel,
    required this.priceLabel,
    required this.title,
    required this.locationLabel,
    required this.onViewDetails,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: thumbnailUrl != null
                      ? CachedNetworkImage(
                          imageUrl: thumbnailUrl!,
                          fit: BoxFit.cover,
                          // Grid column is at most 190 (maxCrossAxisExtent in
                          // view_all_screen.dart) — cap decode to that on an
                          // infinite-scroll grid instead of caching full-size
                          // source photos per item.
                          memCacheWidth: (190 * MediaQuery.of(context).devicePixelRatio).round(),
                          memCacheHeight: (130 * MediaQuery.of(context).devicePixelRatio).round(),
                          placeholder: (_, __) => Container(color: AppColors.surface),
                          errorWidget: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
                Positioned(
                  top: 7,
                  left: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      badgeLabel,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                  ),
                ),
                Positioned(
                  top: 7,
                  right: 7,
                  child: GestureDetector(
                    onTap: onViewDetails,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), shape: BoxShape.circle),
                      child: const Icon(Iconsax.eye, size: 14, color: AppColors.primary),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 22, 10, 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.68)],
                      ),
                    ),
                    child: Text(
                      priceLabel,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textDark),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Iconsax.location, size: 9, color: AppColors.primaryLight),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 9.5, color: AppColors.textLight, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                GestureDetector(
                  onTap: onChat,
                  child: Container(
                    width: double.infinity,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(9)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Iconsax.message_text, size: 10, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Chat', style: TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                      ],
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

  static Widget _placeholder() => Container(
        color: AppColors.surface,
        child: const Center(child: Icon(Icons.home_rounded, size: 28, color: AppColors.primaryLight)),
      );
}
