import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../template/fitness_app_theme.dart';
import '../tokens/design_scale.dart';
import '../tokens/listing_palette.dart';

abstract final class Ink3D {
  static const Color title = Color(0xFF17262A);
  static const Color body = Color(0xFF253840);
  static const Color sub = Color(0xFF4A6572);
  static const Color grey = Color(0xFF767676);
  static const Color copy = Color(0xFF6A6A6A);
  static const Color hint = Color(0xFF9A9A9A);
  static const Color line = Color(0xFFEEF0F4);
  static const Color soft = Color(0x669E9E9E);
  static const Color dim = Color(0x8014182A);
  static const String font = FitnessAppTheme.fontName;

  static const List<String> fallback = ['WorkSans'];

  static TextStyle text(double size, FontWeight weight, Color color, {double? height, double letterSpacing = 0.2, bool scaled = true}) =>
      TextStyle(fontFamily: font, fontFamilyFallback: fallback, fontSize: DS.f(size, scaled: scaled), fontWeight: weight, color: color, height: height, letterSpacing: letterSpacing);

  static const List<BoxShadow> softShadow = [BoxShadow(color: soft, offset: Offset(3, 5), blurRadius: 10)];
  static const List<BoxShadow> topEdge = [BoxShadow(color: Color(0x599E9E9E), offset: Offset(0, -2), blurRadius: 16)];
  static const List<BoxShadow> whiteBtn = [BoxShadow(color: Color(0x33000000), offset: Offset(3, 5), blurRadius: 8)];
  static const List<BoxShadow> goBtn = [BoxShadow(color: Color(0x66213333), offset: Offset(8, 8), blurRadius: 8)];
}

class ListingTone {
  const ListingTone({required this.g1, required this.g2, required this.shadow, required this.haloBase, required this.text, Color? button}) : button = button ?? g2;

  final Color g1;
  final Color g2;
  final Color shadow;
  final Color haloBase;
  final Color text;
  final Color button;

  LinearGradient get gradient => LinearGradient(colors: [g1, g2], begin: Alignment.topLeft, end: Alignment.bottomRight);
  Color get halo => haloBase.withValues(alpha: ListingPalette.haloAlpha);
  Color get tint => haloBase.withValues(alpha: 0.12);

  List<BoxShadow> glow({double blur = 10, double dy = 4, bool scaled = true}) =>
      [BoxShadow(color: shadow, offset: DS.shadowOffset(Offset(1.1, dy), scaled: scaled), blurRadius: DS.shadowBlur(blur, scaled: scaled))];

  factory ListingTone.palette(ListingPalette p) =>
      ListingTone(g1: p.g1, g2: p.g2, shadow: p.glowShadow, haloBase: p.shadow, text: p.text);

  factory ListingTone.meals(MealsGradient m) =>
      ListingTone(g1: m.g1, g2: m.g2, shadow: m.shadowColor, haloBase: m.shadow, text: m.button, button: m.button);

  static final ListingTone indigo = ListingTone.palette(ListingPalette.indigo);
  static final ListingTone forest = ListingTone.palette(ListingPalette.forest);
  static final ListingTone coral = ListingTone.palette(ListingPalette.coral);
  static final ListingTone sunrise = ListingTone.palette(ListingPalette.sunrise);
  static final ListingTone cA = ListingTone.meals(MealsGradient.cA);
  static final ListingTone cB = ListingTone.meals(MealsGradient.cB);
  static final ListingTone cC = ListingTone.meals(MealsGradient.cC);
  static final ListingTone cD = ListingTone.meals(MealsGradient.cD);
  static final ListingTone cE = ListingTone.meals(MealsGradient.cE);
  static final ListingTone cF = ListingTone.meals(MealsGradient.cF);
  static final ListingTone teal = ListingTone(g1: ListingPalette.teal.g1, g2: ListingPalette.teal.g2, shadow: ListingPalette.teal.g2.withValues(alpha: 0.6), haloBase: ListingPalette.teal.g2, text: ListingPalette.teal.text);

  static ListingTone at(int i) => [cA, cB, cC, cD, cE, cF][i % 6];

  static ListingTone list(ListingTone page, int i) {
    if (identical(page, forest)) return [cE, cB, cC][i % 3];
    if (identical(page, coral)) return [cA, cB, cC][i % 3];
    return at(i);
  }
}

class ArtLift {
  static const Map<String, double> _top = {
    'bed': 0.25,
    'automobile': 0.28,
    'camera': 0.28,
    'taxi': 0.21,
    'bus': 0.19,
    'speech_balloon': 0.10,
    'world_map': 0.09,
    'tent': 0.11,
    'beach_with_umbrella': 0.09,
    'locomotive': 0.06,
    'mountain': 0.06,
  };

  static double of(String asset, double size) {
    final name = asset.split('/').last.replaceAll('.png', '');
    return (_top[name] ?? 0) * size;
  }
}

class Art3D extends StatelessWidget {
  const Art3D({
    super.key,
    required this.asset,
    this.size = 100,
    this.halo,
    this.haloColor,
    this.haloDy,
    this.shadowBlur = 6,
    this.shadowOffset = const Offset(5, 8),
    this.shadowAlpha = 0.25,
    this.scaled = true,
  });

  final String asset;
  final double size;
  final double? halo;
  final Color? haloColor;
  final double? haloDy;
  final double shadowBlur;
  final Offset shadowOffset;
  final double shadowAlpha;
  final bool scaled;

  @override
  Widget build(BuildContext context) {
    final size = DS.s(this.size, scaled: scaled);
    final shadowBlur = DS.shadowBlur(this.shadowBlur, scaled: scaled);
    final shadowOffset = DS.shadowOffset(this.shadowOffset, scaled: scaled);
    final h = halo == null ? null : DS.s(halo!, scaled: scaled);
    final image = Image.asset(asset, width: size, height: size, fit: BoxFit.contain);
    final shadow = Transform.translate(
      offset: shadowOffset,
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: shadowBlur / 2, sigmaY: shadowBlur / 2),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: shadowAlpha), BlendMode.srcIn),
          child: image,
        ),
      ),
    );
    final art = SizedBox(width: size, height: size, child: Stack(clipBehavior: Clip.none, children: [Positioned.fill(child: shadow), Positioned.fill(child: image)]));
    if (h == null) return art;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: (size - h) / 2,
            top: (size - h) / 2 + DS.s(haloDy ?? 0, scaled: scaled),
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: haloColor ?? Colors.white.withValues(alpha: 0.22)),
              child: SizedBox(width: h, height: h),
            ),
          ),
          art,
        ],
      ),
    );
  }
}

class PhotoSticker extends StatelessWidget {
  const PhotoSticker({
    super.key,
    required this.photo,
    required this.sticker,
    this.size = 100,
    this.border = 3,
    this.stickerSize,
    this.stickerOffset,
    this.scaled = true,
  });

  final Widget photo;
  final String sticker;
  final double size;
  final double border;
  final double? stickerSize;
  final Offset? stickerOffset;
  final bool scaled;

  @override
  Widget build(BuildContext context) {
    final size = DS.s(this.size, scaled: scaled);
    final border = DS.s(this.border, scaled: scaled);
    final s = stickerSize == null ? size * 0.52 : DS.s(stickerSize!, scaled: scaled);
    final o = stickerOffset == null ? Offset(size * 0.66, size * 0.64) : DS.shadowOffset(stickerOffset!, scaled: scaled);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: DS.shadows(const [BoxShadow(color: Color(0x47000000), offset: Offset(3, 6), blurRadius: 10)], scaled: scaled),
              ),
              child: Padding(padding: EdgeInsets.all(border), child: ClipOval(child: SizedBox.expand(child: photo))),
            ),
          ),
          if (sticker.isNotEmpty)
            Positioned(
              left: o.dx,
              top: o.dy,
              child: Art3D(asset: sticker, size: s, shadowBlur: DS.s(3, scaled: scaled), shadowOffset: DS.shadowOffset(const Offset(2, 4), scaled: scaled), shadowAlpha: 0.3, scaled: false),
            ),
        ],
      ),
    );
  }
}
