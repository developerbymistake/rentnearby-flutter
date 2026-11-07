import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../config/app_colors.dart';
import '../../../config/app_shadows.dart';
import '../models/trip_spot_category.dart';
import '../models/trip_spot_model.dart';
import '../trip_colors.dart';
import '../utils/trip_format.dart';
import 'trip_spot_detail_sheet.dart';

class TripSpotRow extends StatelessWidget {
  final TripSpotModel spot;
  final bool selected;
  final VoidCallback? onToggle;
  final bool locked;

  const TripSpotRow({super.key, required this.spot, required this.selected, this.onToggle, this.locked = false});

  @override
  Widget build(BuildContext context) {
    final description = spot.description;
    final area = spot.area;
    final extra = spot.gallery.length - 1;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => TripSpotDetailSheet.show(context, spot: spot, selected: selected, locked: locked, onToggle: onToggle),
      child: Container(
        height: 188,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? TripColors.accent : Colors.transparent, width: 1.6),
          boxShadow: AppShadows.premium(TripColors.accent, alpha: 0.08, blur: 10, offset: const Offset(0, 3)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              TripSpotMedia(spot: spot),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x22000000), Color(0xCC000000)],
                    stops: [0.3, 0.55, 1],
                  ),
                ),
              ),
              Positioned(left: 10, top: 10, child: _chip(TripSpotCategory.label(spot.category))),
              if (extra > 0)
                Positioned(right: 10, top: 10, child: _chip('+$extra', icon: Icons.photo_library_outlined)),
              Positioned(
                left: 12,
                right: 64,
                bottom: 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    Text(
                      [if (area != null && area.isNotEmpty) area, '~${TripFormat.visit(spot.visitMinutes)}'].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Colors.white70),
                    ),
                    if (description != null && description.isNotEmpty)
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: Colors.white),
                      ),
                  ],
                ),
              ),
              Positioned(
                right: 10,
                bottom: 10,
                child: TripSpotAddButton(selected: selected, locked: locked, onTap: onToggle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, {IconData? icon}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 12, color: Colors.white), const SizedBox(width: 3)],
            Text(
              label,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ),
      );
}

class TripSpotAddButton extends StatelessWidget {
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;

  const TripSpotAddButton({super.key, required this.selected, required this.locked, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? TripColors.accent : Colors.white,
          border: Border.all(color: locked && !selected ? AppColors.divider : TripColors.accent, width: 1.4),
        ),
        child: Icon(
          selected ? Icons.check_rounded : Icons.add_rounded,
          size: 22,
          color: selected ? Colors.white : (locked ? AppColors.textHint : TripColors.accentDark),
        ),
      ),
    );
  }
}

class TripSpotMedia extends StatelessWidget {
  final TripSpotModel spot;
  final String? url;

  const TripSpotMedia({super.key, required this.spot, this.url});

  @override
  Widget build(BuildContext context) {
    final src = url ?? (spot.hasPhoto ? spot.gallery.first : null);
    if (src == null || src.isEmpty) return _fallback();
    return CachedNetworkImage(
      imageUrl: src,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: AppColors.surfaceWarm),
      errorWidget: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() {
    final color = TripSpotCategory.colorOf(spot.category);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.75)],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(TripSpotCategory.iconOf(spot.category), size: 56, color: Colors.white.withValues(alpha: 0.9)),
    );
  }
}
