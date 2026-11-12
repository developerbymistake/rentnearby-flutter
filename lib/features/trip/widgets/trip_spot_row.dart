import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../models/trip_spot_category.dart';
import '../models/trip_spot_model.dart';
import '../trip_strings_spots_x.dart';
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
    final hasArea = area != null && area.isNotEmpty;
    final tone = KitTone.trip;
    return PressScale(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => TripSpotDetailSheet.show(context, spot: spot, selected: selected, locked: locked, onToggle: onToggle),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.fastOutSlowIn,
          decoration: BoxDecoration(
            color: DesignColors.surface,
            borderRadius: CardRadius.tile,
            border: Border.all(color: selected ? tone.accentDark : Colors.transparent, width: 2),
            boxShadow: selected ? ShadowTokens.elev3 : ShadowTokens.elev2,
          ),
          child: ClipRRect(
            borderRadius: CardRadius.tile,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: spot.hasPhoto ? 2.2 : 3.4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      TripSpotMedia(spot: spot),
                      Positioned(
                        left: 10,
                        top: 10,
                        right: extra > 0 ? 76 : 36,
                        child: Row(
                          children: [
                            if (spot.isFeatured) ...[const TripFeaturedChip(), const SizedBox(width: 6)],
                            Flexible(child: _chip(TripSpotCategory.label(spot.category))),
                          ],
                        ),
                      ),
                      if (extra > 0) Positioned(right: 32, top: 10, child: _chip('+$extra', asset: TravelIcon.photo)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              spot.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TypeTokens.style(16, FontWeight.w700, color: DesignColors.textStrong, letterSpacing: 0.18),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (hasArea) ...[const TravelIcon(TravelIcon.pin, size: 14), const SizedBox(width: 4)],
                                Expanded(
                                  child: Text(
                                    [if (hasArea) area, '~${TripFormat.visit(spot.visitMinutes)}'].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TypeTokens.style(12, FontWeight.w500, color: TypeTokens.secondary),
                                  ),
                                ),
                              ],
                            ),
                            if (description != null && description.isNotEmpty)
                              Text(
                                description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TypeTokens.style(12, FontWeight.w400, color: TypeTokens.secondary),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TripSpotAddButton(selected: selected, locked: locked, onTap: onToggle),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, {String? asset}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: DesignColors.tint(DesignColors.textInk, Alpha.v55), borderRadius: CardRadius.chip),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (asset != null) ...[TravelIcon(asset, size: 12), const SizedBox(width: 3)],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TypeTokens.style(11, FontWeight.w600, color: DesignColors.surface),
              ),
            ),
          ],
        ),
      );
}

class TripFeaturedChip extends StatelessWidget {
  const TripFeaturedChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: KitTone.trip.accentDark, borderRadius: CardRadius.chip),
      child: Text(
        '★ ${TripStringsSpotsX.featured}',
        maxLines: 1,
        style: TypeTokens.style(10, FontWeight.w700, color: DesignColors.surface, chip: true),
      ),
    );
  }
}

class TripSpotAddButton extends StatelessWidget {
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;

  const TripSpotAddButton({super.key, required this.selected, required this.locked, this.onTap});

  @override
  Widget build(BuildContext context) {
    final off = locked && !selected;
    final accent = KitTone.trip.accentDark;
    final fg = selected ? DesignColors.onPrimary : (off ? DesignColors.textMuted : accent);
    return PressScale(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: KitMetrics.touch),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.fastOutSlowIn,
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: CardRadius.pill,
                color: selected ? accent : DesignColors.surface,
                border: Border.all(color: off ? DesignColors.divider : accent, width: 1.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(selected ? Icons.check_rounded : Icons.add_rounded, size: 18, color: fg),
                  const SizedBox(width: 4),
                  Text(
                    selected ? TripStringsSpotsX.addedWishlist : TripStringsSpotsX.addWishlist,
                    maxLines: 1,
                    style: TypeTokens.style(12, FontWeight.w600, color: fg, letterSpacing: 0.27),
                  ),
                ],
              ),
            ),
          ),
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
      placeholder: (_, _) => const TemplatePlaceholder(height: double.infinity, radius: 0),
      errorWidget: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() => PlaceholderTile(
        tone: KitTone.trip,
        gradient: TripSpotLook.hashedGradient(spot.category),
        asset: TripSpotLook.assetOf(spot.category),
        iconSize: 56,
      );
}
