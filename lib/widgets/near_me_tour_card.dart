import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../config/app_colors.dart';

/// Bottom card for the "Find Near Me" tour — purely presentational (data +
/// callbacks in, same pattern as EmptyRadiusHint), so it's safe to share
/// between the Room and Plot Explore screens despite their different theming.
/// Prev/Next are a full-width labelled bar (not small icons) so they read as
/// unmistakable controls, with a second "Cancel search" link directly under
/// them — cancel is reachable wherever the thumb already is.
class NearMeTourCard extends StatelessWidget {
  final Color accentColor;
  final String? thumbnailUrl;
  final IconData thumbnailIcon;
  final String title;
  final String subtitle;
  final double distanceKm;
  final int currentIndex;
  final int total;
  final bool isFirstResult;
  final bool isLastResult;
  final bool showHandoff;
  final int remainingCount;
  final String handoffTypeLabel;
  final VoidCallback onTapCard;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onCancel;
  final VoidCallback? onSeeAll;

  const NearMeTourCard({
    super.key,
    required this.accentColor,
    required this.thumbnailUrl,
    required this.thumbnailIcon,
    required this.title,
    required this.subtitle,
    required this.distanceKm,
    required this.currentIndex,
    required this.total,
    required this.isFirstResult,
    required this.isLastResult,
    required this.showHandoff,
    required this.remainingCount,
    required this.handoffTypeLabel,
    required this.onTapCard,
    required this.onPrev,
    required this.onNext,
    required this.onCancel,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(total, (i) {
            final on = i == currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: on ? 16 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: on ? accentColor : AppColors.divider,
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: showHandoff
              ? _buildHandoff()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onTapCard,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: thumbnailUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: thumbnailUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: AppColors.surface),
                                      errorWidget: (_, __, ___) => _placeholder(),
                                    )
                                  : _placeholder(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textDark),
                                ),
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Iconsax.location, size: 9, color: accentColor),
                                      const SizedBox(width: 3),
                                      Text('${distanceKm.toStringAsFixed(1)} km away',
                                          style: TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.w700, color: accentColor)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(subtitle,
                                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _NavButton(
                            label: 'Prev',
                            icon: Iconsax.arrow_left_2,
                            iconLeading: true,
                            enabled: !isFirstResult,
                            background: AppColors.surface,
                            foreground: isFirstResult ? AppColors.textHint : AppColors.textMedium,
                            onTap: onPrev,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _NavButton(
                            label: 'Next',
                            icon: Iconsax.arrow_right_3,
                            iconLeading: false,
                            enabled: !isLastResult,
                            background: accentColor,
                            foreground: Colors.white,
                            onTap: onNext,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    GestureDetector(
                      onTap: onCancel,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.close_rounded, size: 12, color: AppColors.error),
                          const SizedBox(width: 4),
                          const Text('Cancel search',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildHandoff() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text("That's the $total closest",
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(height: 3),
        Text('$remainingCount more $handoffTypeLabel nearby',
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textLight)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: onSeeAll,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(11)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('See all $remainingCount more',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(width: 6),
                  const Icon(Iconsax.arrow_right_3, size: 13, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        GestureDetector(
          onTap: onCancel,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.close_rounded, size: 12, color: AppColors.error),
              const SizedBox(width: 4),
              const Text('Cancel search',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.surface,
        child: Icon(thumbnailIcon, size: 20, color: accentColor),
      );
}

class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool iconLeading;
  final bool enabled;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.iconLeading,
    required this.enabled,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final children = [
      Icon(icon, size: 13, color: foreground),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.w700, color: foreground)),
    ];
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: enabled ? background : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: iconLeading ? children : children.reversed.toList(),
        ),
      ),
    );
  }
}
