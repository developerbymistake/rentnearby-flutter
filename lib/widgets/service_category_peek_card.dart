import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_shadows.dart';
import '../models/service_category_model.dart';
import '../utils/service_icons.dart';
import 'service_zone.dart';

class ServiceCategoryPeekCard extends StatelessWidget {
  final ServiceCategoryModel category;
  final ServiceZone zone;
  final int serviceCount;
  final VoidCallback onTap;

  const ServiceCategoryPeekCard({
    super.key,
    required this.category,
    required this.zone,
    required this.serviceCount,
    required this.onTap,
  });

  static const _cardWidth = 140.0;
  static const _cardHeight = 168.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: _cardWidth + 14,
        height: _cardHeight + 14,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(top: 14, left: 14, child: _peekLayer(angle: 0.07, alpha: 0.08, blur: 6)),
            Positioned(top: 7, left: 7, child: _peekLayer(angle: 0.035, alpha: 0.10, blur: 8)),
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: _cardWidth,
                height: _cardHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.premium(AppColors.textDark, alpha: 0.14, blur: 16, offset: const Offset(0, 6)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      category.coverPhotoUrl.isEmpty
                          ? _placeholder()
                          : CachedNetworkImage(
                              imageUrl: category.coverPhotoUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, _) => _placeholder(),
                              errorWidget: (_, _, _) => _placeholder(),
                            ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            '$serviceCount',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 8.5, fontWeight: FontWeight.w800, color: zone.accent),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(8, 16, 8, 7),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Color(0xB3000000), Colors.transparent],
                            ),
                          ),
                          child: Text(
                            category.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _peekLayer({required double angle, required double alpha, required double blur}) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: _cardWidth,
        height: _cardHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.premium(AppColors.textDark, alpha: alpha, blur: blur, offset: const Offset(0, 2)),
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: zone.imgBg,
        child: Center(child: Icon(serviceIconFor(category.iconName), size: 26, color: zone.accent)),
      );
}

class ServiceCategoryPeekCardShimmer extends StatelessWidget {
  const ServiceCategoryPeekCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 18,
        runSpacing: 18,
        children: List.generate(
          6,
          (_) => Shimmer.fromColors(
            baseColor: AppColors.shimmerBase,
            highlightColor: AppColors.shimmerHighlight,
            child: Container(
              width: ServiceCategoryPeekCard._cardWidth,
              height: ServiceCategoryPeekCard._cardHeight,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
      ),
    );
  }
}
