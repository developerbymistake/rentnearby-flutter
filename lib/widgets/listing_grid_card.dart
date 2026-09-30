import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';
import '../config/app_shadows.dart';

class ListingGridCard extends StatelessWidget {
  static const double height = 240;

  final String? thumbnailUrl;
  final String tagLabel;
  final String title;
  final String locationLabel;
  final List<String> facts;
  final String priceCaption;
  final String priceValue;
  final String priceUnit;
  final bool isPlot;
  final VoidCallback onViewDetails;

  const ListingGridCard({
    super.key,
    required this.thumbnailUrl,
    required this.tagLabel,
    required this.title,
    required this.locationLabel,
    required this.facts,
    required this.priceCaption,
    required this.priceValue,
    required this.priceUnit,
    required this.isPlot,
    required this.onViewDetails,
  });

  Color get _accent => isPlot ? AppColors.plot : AppColors.primary;
  Color get _accentDark => isPlot ? AppColors.plotDark : AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.8)),
        boxShadow: AppShadows.premium(AppColors.primary, alpha: 0.05, blur: 8, offset: const Offset(0, 2)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onViewDetails,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 104,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    thumbnailUrl != null
                        ? CachedNetworkImage(
                            imageUrl: thumbnailUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: (190 * dpr).round(),
                            memCacheHeight: (104 * dpr).round(),
                            placeholder: (_, __) => _placeholder(),
                            errorWidget: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(999)),
                        child: Text(
                          tagLabel,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Iconsax.location, size: 10, color: AppColors.textLight),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.textLight),
                          ),
                        ),
                      ],
                    ),
                    if (facts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var i = 0; i < facts.length; i++) ...[
                            if (i > 0) const SizedBox(width: 4),
                            Flexible(child: _factChip(facts[i])),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(height: 1, color: AppColors.divider.withValues(alpha: 0.6)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  priceCaption,
                                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textLight),
                                ),
                                const SizedBox(height: 2),
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: priceValue,
                                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.gold),
                                      ),
                                      TextSpan(
                                        text: priceUnit,
                                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 8.5, fontWeight: FontWeight.w600, color: AppColors.textLight),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Iconsax.arrow_right_3, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _factChip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: _accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w600, color: _accentDark),
        ),
      );

  Widget _placeholder() => Container(
        color: isPlot ? AppColors.plotSurface : AppColors.surface,
        child: Center(
          child: Icon(isPlot ? Icons.landscape_rounded : Icons.home_rounded, size: 30, color: _accent.withValues(alpha: 0.5)),
        ),
      );
}
