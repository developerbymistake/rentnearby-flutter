import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../utils/photo_url.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/design_scale.dart';
import '../tokens/shadow_tokens.dart';
import 'art_3d.dart';
import 'card_kit.dart';
import 'travel_icon.dart';

class PhotoCircle extends StatelessWidget {
  const PhotoCircle({
    super.key,
    required this.url,
    required this.art,
    this.size = 136,
    this.photoSize,
    this.artSize,
    this.tone,
    this.haloColor,
    this.star = false,
    this.starSize,
    this.starOffset,
    this.semanticsLabel,
  });

  final String? url;
  final String art;
  final double size;
  final double? photoSize;
  final double? artSize;
  final ListingTone? tone;
  final Color? haloColor;
  final bool star;
  final double? starSize;
  final Offset? starOffset;
  final String? semanticsLabel;

  static const Key starKey = ValueKey('photo-circle-star');
  static const Key photoKey = ValueKey('photo-circle-photo');
  static const Key artKey = ValueKey('photo-circle-art');
  static const double photoRatio = 0.865;
  static const double artRatio = 0.88;
  static const double starRatio = 0.32;
  static const double ring = 3;
  static const Duration fadeIn = Duration(milliseconds: 120);

  static bool hasPhoto(String? url) => PhotoUrl.parse(url) != null;

  static int decodeWidth(double photoSize, double dpr) => math.min(KitPhoto.maxDecodePx, (DS.s(photoSize) * dpr).round());

  double get _photo => photoSize ?? size * photoRatio;
  double get _art => artSize ?? size * artRatio;

  Widget _artLayer() {
    final a = _art;
    return SizedBox.square(
      dimension: DS.s(size),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: DS.s((size - a) / 2),
            top: DS.s((size - a) / 2 + size * 0.03),
            child: Art3D(key: artKey, asset: art, size: a),
          ),
        ],
      ),
    );
  }

  Widget _photoLayer(BuildContext context, String src) {
    final p = DS.s(_photo);
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    return CachedNetworkImage(
      key: photoKey,
      imageUrl: src,
      width: DS.s(size),
      height: DS.s(size),
      memCacheWidth: decodeWidth(_photo, dpr),
      fadeInDuration: fadeIn,
      placeholder: (_, _) => _artLayer(),
      errorWidget: (_, _, _) => _artLayer(),
      imageBuilder: (_, image) => Center(
        child: Container(
          width: p,
          height: p,
          padding: EdgeInsets.all(DS.s(ring)),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: DesignColors.surface,
            boxShadow: DS.shadows([BoxShadow(color: Colors.black.withValues(alpha: Alpha.soft), offset: const Offset(3, 5), blurRadius: 8)]),
          ),
          child: ClipOval(child: Image(image: image, fit: BoxFit.cover, width: p, height: p)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = DS.s(size);
    final src = PhotoUrl.parse(url);
    final s = starSize ?? size * starRatio;
    final o = starOffset ?? Offset(size * 0.71, -size * 0.15);
    final halo = haloColor ?? tone?.halo ?? DesignColors.onPrimary.withValues(alpha: Alpha.v22);
    Widget child = SizedBox.square(
      dimension: box,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: halo))),
          Positioned.fill(child: src == null ? _artLayer() : _photoLayer(context, src)),
          if (star)
            Positioned(
              left: DS.s(o.dx),
              top: DS.s(o.dy),
              child: Container(
                key: starKey,
                width: DS.s(s),
                height: DS.s(s),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DesignColors.surface,
                  boxShadow: DS.shadows(ShadowTokens.tight(tone?.shadow ?? DesignColors.shadowBase)),
                ),
                alignment: Alignment.center,
                child: TravelIcon(TravelIcon.star, size: s * 0.59),
              ),
            ),
        ],
      ),
    );
    child = IgnorePointer(child: child);
    final label = semanticsLabel;
    if (label == null || label.isEmpty) return ExcludeSemantics(child: child);
    return Semantics(label: label, image: true, child: ExcludeSemantics(child: child));
  }
}
