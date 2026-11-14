import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import '../models/trip_spot_category.dart';
import '../models/trip_spot_model.dart';
import '../trip_strings_spots_x.dart';
import 'trip_spot_detail_sheet.dart';

class TripSpotRow extends StatelessWidget {
  final TripSpotModel spot;
  final bool selected;
  final VoidCallback? onToggle;
  final bool locked;

  const TripSpotRow({super.key, required this.spot, required this.selected, this.onToggle, this.locked = false});

  static const String details = 'Details';

  @override
  Widget build(BuildContext context) {
    final extra = spot.gallery.length - 1;
    final cat = TripSpotCategory.label(spot.category);
    final off = locked && !selected;
    void open() => TripSpotDetailSheet.show(context, spot: spot, selected: selected, locked: locked, onToggle: onToggle);
    return WideCard(
      tone: ListingTone.indigo,
      kind: WideKind.photo,
      photo: spot.hasPhoto
          ? Stack(
              fit: StackFit.expand,
              children: [
                TripSpotMedia(spot: spot),
                if (extra > 0) Positioned(right: 12, top: 12, child: TripPhotoCount(count: extra)),
              ],
            )
          : null,
      sticker: TripSpotLook.assetOf(spot.category),
      badge: spot.isFeatured ? '${TripStringsSpotsX.featured} · $cat' : cat,
      tag: cat,
      title: spot.title,
      subtitle: spot.description ?? '',
      showPrice: false,
      picked: selected,
      dimmed: off,
      onTap: open,
      actions: [
        WideAction(icon: Icons.info_outline_rounded, label: details, onTap: open),
        WideAction(
          icon: selected ? Icons.check_rounded : Icons.add_rounded,
          label: selected ? TripStringsSpotsX.addedWishlist : TripStringsSpotsX.addWishlist,
          selected: selected,
          onTap: onToggle,
        ),
      ],
    );
  }
}

class TripPhotoCount extends StatelessWidget {
  final int count;

  const TripPhotoCount({super.key, required this.count});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: DesignColors.tint(DesignColors.textInk, Alpha.v55), borderRadius: CardRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Art3D(asset: ListingArt.camera, size: 16, shadowBlur: 0),
              const SizedBox(width: 4),
              Text('+$count', maxLines: 1, style: Ink3D.text(11.5, FontWeight.w700, DesignColors.surface)),
            ],
          ),
        ),
      );
}

class TripFeaturedChip extends StatelessWidget {
  const TripFeaturedChip({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: CardRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          TripStringsSpotsX.featured,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Ink3D.text(11, FontWeight.w700, ListingTone.indigo.text),
        ),
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
    final tone = ListingTone.indigo;
    final label = selected ? TripStringsSpotsX.addedWishlist : TripStringsSpotsX.addWishlist;
    return Opacity(
      opacity: off ? Alpha.v45 : 1,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Tap3D(
          onTap: onTap,
          label: label,
          selected: selected,
          child: SizedBox(
            width: KitMetrics.touch,
            height: KitMetrics.touch,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DesignColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: off ? null : [BoxShadow(color: tone.shadow, offset: const Offset(1, 4), blurRadius: 8)],
                ),
                child: Icon(selected ? Icons.check_rounded : Icons.add_rounded, size: 24, color: tone.button),
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

  Widget _fallback() => DecoratedBox(
        decoration: BoxDecoration(gradient: ListingTone.indigo.gradient),
        child: Center(child: Art3D(asset: TripSpotLook.assetOf(spot.category), size: 84)),
      );
}
