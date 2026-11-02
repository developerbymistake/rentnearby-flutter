import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_shadows.dart';
import '../../../widgets/plan_badge_chip.dart';
import '../models/trip_spot_category.dart';
import '../models/trip_spot_model.dart';
import '../trip_colors.dart';
import '../utils/trip_format.dart';

class TripSpotRow extends StatelessWidget {
  final TripSpotModel spot;
  final bool selected;
  final VoidCallback? onToggle;

  const TripSpotRow({super.key, required this.spot, required this.selected, this.onToggle});

  @override
  Widget build(BuildContext context) {
    final description = spot.description;
    final area = spot.area;
    final credit = _credit();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? TripColors.accent.withValues(alpha: 0.45) : AppColors.divider.withValues(alpha: 0.7),
          ),
          boxShadow: AppShadows.premium(TripColors.accent, alpha: 0.05, blur: 8, offset: const Offset(0, 2)),
        ),
        child: Row(
          children: [
            _leading(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          spot.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark),
                        ),
                      ),
                      if (spot.isFeatured) ...[
                        const SizedBox(width: 6),
                        const PlanBadgeChip(color: TripColors.accentDark),
                      ],
                    ],
                  ),
                  if (description != null && description.isNotEmpty)
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight),
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _meta(TripSpotCategory.label(spot.category)),
                      if (area != null && area.isNotEmpty) _meta(area),
                      _meta(TripFormat.visit(spot.visitMinutes)),
                    ],
                  ),
                  if (credit != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        credit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textLight),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _pill(),
          ],
        ),
      ),
    );
  }

  String? _credit() {
    final url = spot.imageUrl;
    final by = spot.imageCredit?.trim();
    if (url == null || url.isEmpty || by == null || by.isEmpty) return null;
    final licence = spot.imageLicense?.trim();
    return licence == null || licence.isEmpty ? '© $by' : '© $by · $licence';
  }

  Widget _leading() {
    final icon = Icon(TripSpotCategory.iconOf(spot.category), size: 22, color: TripSpotCategory.colorOf(spot.category));
    final url = spot.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        color: TripColors.surface,
        alignment: Alignment.center,
        child: url == null || url.isEmpty
            ? icon
            : CachedNetworkImage(
                imageUrl: url,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: AppColors.surfaceWarm),
                errorWidget: (_, _, _) => icon,
              ),
      ),
    );
  }

  Widget _meta(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: AppColors.neutralChip, borderRadius: BorderRadius.circular(6)),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.neutralChipText),
        ),
      );

  Widget _pill() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? TripColors.accent : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TripColors.accent, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            const Icon(Icons.check_rounded, size: 13, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            selected ? 'Added' : 'Add to list',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : TripColors.accentDark,
            ),
          ),
        ],
      ),
    );
  }
}
