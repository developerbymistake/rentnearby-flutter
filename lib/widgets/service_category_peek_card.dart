import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';
import '../config/app_shadows.dart';
import '../models/service_category_model.dart';
import '../utils/service_icons.dart';
import 'service_zone.dart';

const _kAspectRatio = 168 / 140;
const _kPeekInsetRatio = 14 / 140;

class ServiceCategoryPeekCard extends StatelessWidget {
  final ServiceCategoryModel category;
  final ServiceZone zone;
  final int serviceCount;
  final VoidCallback onTap;
  final double cardWidth;

  const ServiceCategoryPeekCard({
    super.key,
    required this.category,
    required this.zone,
    required this.serviceCount,
    required this.onTap,
    required this.cardWidth,
  });

  double get _cardHeight => cardWidth * _kAspectRatio;
  double get _peekInset => cardWidth * _kPeekInsetRatio;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: cardWidth + _peekInset,
        height: _cardHeight + _peekInset,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(top: _peekInset, left: _peekInset, child: _peekLayer(angle: 0.07, alpha: 0.08, blur: 6)),
            Positioned(top: _peekInset / 2, left: _peekInset / 2, child: _peekLayer(angle: 0.035, alpha: 0.10, blur: 8)),
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: cardWidth,
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
        width: cardWidth,
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
        child: Center(child: Icon(serviceIconFor(category.iconName), size: cardWidth * 0.19, color: zone.accent)),
      );
}

class ServiceCategoryPeekCardShimmer extends StatelessWidget {
  const ServiceCategoryPeekCardShimmer({super.key});

  static const _spacing = 14.0;
  static const _columns = 2;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = (constraints.maxWidth - _spacing * (_columns - 1)) / _columns;
          return Wrap(
            spacing: _spacing,
            runSpacing: _spacing,
            children: List.generate(
              6,
              (_) => Shimmer.fromColors(
                baseColor: AppColors.shimmerBase,
                highlightColor: AppColors.shimmerHighlight,
                child: Container(
                  width: cardWidth,
                  height: cardWidth * _kAspectRatio,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
