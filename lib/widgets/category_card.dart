import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../models/service_category_model.dart';
import 'service_zone.dart';

class CategoryCard extends StatelessWidget {
  final ServiceCategoryModel category;
  final ServiceZone zone;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.category,
    required this.zone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = category.coverPhotoUrl.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: SizedBox(
                height: 100,
                width: double.infinity,
                child: hasPhoto
                    ? CachedNetworkImage(
                        imageUrl: category.coverPhotoUrl,
                        fit: BoxFit.cover,
                        memCacheWidth:
                            (140 * MediaQuery.of(context).devicePixelRatio)
                                .round(),
                        memCacheHeight:
                            (100 * MediaQuery.of(context).devicePixelRatio)
                                .round(),
                        placeholder: (_, __) => Container(color: zone.imgBg),
                        errorWidget: (_, __, ___) => _iconFallback(),
                      )
                    : _iconFallback(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconFallback() => Container(
    color: zone.imgBg,
    child: Icon(Iconsax.category, size: 32, color: zone.accent),
  );
}

class CategoryCardShimmer extends StatelessWidget {
  const CategoryCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
