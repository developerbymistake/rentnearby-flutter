import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/utils/spot_photo_url.dart';
import '../models/trip_spot_category.dart';
import '../models/trip_spot_model.dart';
import '../trip_strings_spots_x.dart';
import 'trip_spot_detail_sheet.dart';

class TripSpotRow extends StatelessWidget {
  final TripSpotModel spot;
  final bool selected;
  final VoidCallback? onToggle;
  final bool locked;
  final String? subtitle;
  final bool dimmed;
  final bool draft;
  final int? cityKey;
  final String? version;

  const TripSpotRow({super.key, required this.spot, required this.selected, this.onToggle, this.locked = false, this.subtitle, this.dimmed = false, this.draft = false, this.cityKey, this.version});

  static const String details = 'Details';

  @override
  Widget build(BuildContext context) {
    final extra = spot.photos.length - 1;
    final cat = TripSpotCategory.label(spot.category);
    final off = locked && !selected;
    void open() => TripSpotDetailSheet.show(context, spot: spot, selected: selected, locked: locked, onToggle: onToggle, cityKey: cityKey, version: version);
    return WideCard(
      tone: ListingTone.indigo,
      kind: WideKind.photo,
      photo: spot.hasPhoto
          ? Stack(
              fit: StackFit.expand,
              children: [
                TripSpotMedia(spot: spot, size: SpotPhotoSize.card),
                if (extra > 0) Positioned(right: DS.s(12), top: DS.s(12), child: TripPhotoCount(count: extra)),
              ],
            )
          : null,
      sticker: TripSpotLook.assetOf(spot.category),
      badge: spot.isFeatured ? '${TripStringsSpotsX.featured} · $cat' : cat,
      tag: cat,
      title: spot.title,
      subtitle: subtitle ?? spot.description ?? '',
      showPrice: false,
      picked: selected,
      dimmed: off || dimmed,
      onTap: open,
      actions: [
        WideAction(icon: Icons.info_outline_rounded, label: details, onTap: open),
        draft
            ? WideAction(
                icon: selected ? Icons.check_rounded : Icons.circle_outlined,
                label: dimmed ? TripStringsSpotsX.addedWishlist : '',
                selected: selected,
                onTap: onToggle,
              )
            : WideAction(
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
        decoration: BoxDecoration(color: DesignColors.tint(DesignColors.textInk, Alpha.v55), borderRadius: DS.br(CardRadius.pill)),
        child: Padding(
          padding: DS.sym(h: 10, v: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Art3D(asset: ListingArt.camera, size: 16, shadowBlur: 0),
              Gap.h(4),
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
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.br(CardRadius.pill)),
      child: Padding(
        padding: DS.sym(h: 10, v: 3),
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
            width: DS.s(KitMetrics.touch),
            height: DS.s(KitMetrics.touch),
            child: Center(
              child: Container(
                width: DS.s(40),
                height: DS.s(40),
                decoration: BoxDecoration(
                  color: DesignColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: off ? null : [BoxShadow(color: tone.shadow, offset: DS.shadowOffset(const Offset(1, 4)), blurRadius: DS.shadowBlur(8))],
                ),
                child: Icon(selected ? Icons.check_rounded : Icons.add_rounded, size: DS.s(24), color: tone.button),
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
  final SpotPhotoSize size;

  const TripSpotMedia({super.key, required this.spot, required this.size, this.url});

  @visibleForTesting
  static Widget Function(String url, BoxFit fit, Widget fallback)? debugImageBuilder;

  @override
  Widget build(BuildContext context) => photo(url ?? (spot.hasPhoto ? spot.photos.first : null), size, fallback(spot));

  static Widget photo(String? src, SpotPhotoSize size, Widget fallback) {
    final sized = SpotPhotoUrl.of(src, size);
    if (sized == null || sized.isEmpty) return fallback;
    final test = debugImageBuilder;
    if (test != null) return test(sized, BoxFit.cover, fallback);
    return LayoutBuilder(
      builder: (context, c) => CachedNetworkImage(
        imageUrl: sized,
        fit: BoxFit.cover,
        memCacheWidth: SpotPhotoUrl.cacheWidth(context, c.maxWidth, size),
        placeholder: (_, _) => const TemplatePlaceholder(height: double.infinity, radius: 0),
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }

  static Widget fallback(TripSpotModel spot) => fallbackArt(TripSpotLook.assetOf(spot.category));

  static Widget fallbackArt(String asset) => DecoratedBox(
        decoration: BoxDecoration(gradient: ListingTone.indigo.gradient),
        child: Center(child: Art3D(asset: asset, size: 84)),
      );
}
