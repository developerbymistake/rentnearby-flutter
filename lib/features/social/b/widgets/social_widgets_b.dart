import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../../../design/extra/ext_chat.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../trip/data/trip_city_catalog.dart';
import '../../../trip/models/trip_city_model.dart';
import '../../../trip/widgets/trip_city_art.dart';

abstract final class SocialLookB {
  static const Color seatsText = BuddyLook.tealEnd;

  static BorderRadius get cardRadius =>
      DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(40), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)));

  static BorderRadius get coverRadius =>
      DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(30), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)));

  static BorderRadius get heroRadius =>
      DS.br(const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(54), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)));

  static const List<String> arts = [ListingArt.mountain, ListingArt.canoe, ListingArt.camping, ListingArt.sunriseMountains];
  static final List<ListingTone> _tones = [ListingTone.indigo, ListingTone.coral, ListingTone.teal, ListingTone.cB];

  static int seedOf(int cityKey, String fallback) => cityKey != 0 ? cityKey.abs() : fallback.hashCode.abs();

  static ListingTone toneOf(int seed) => _tones[seed % _tones.length];

  static String artOf(int seed) => arts[seed % arts.length];
}

abstract final class CityCoverLookup {
  static Object? _key;
  static Map<int, TripCityModel> _byKey = const {};

  static TripCityModel? city(int cityKey) {
    if (cityKey == 0) return null;
    final catalog = TripCityCatalog.to;
    final data = catalog.dataKey;
    if (data == null) return null;
    if (!identical(data, _key)) {
      _key = data;
      _byKey = {for (final c in catalog.search('')) c.cityKey: c};
    }
    return _byKey[cityKey];
  }

  static String? cover(int cityKey) => city(cityKey)?.cover;
}

class TripCoverArt extends StatelessWidget {
  const TripCoverArt({super.key, required this.cityKey, required this.seed, required this.size});

  final int cityKey;
  final int seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cover = CityCoverLookup.cover(cityKey);
    if (cover == null) {
      return ExcludeSemantics(child: Art3D(asset: SocialLookB.artOf(seed), size: size, shadowBlur: 5, shadowOffset: const Offset(3, 6)));
    }
    final box = DS.s(size);
    return ExcludeSemantics(
      child: Container(
        width: box,
        height: box,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: DesignColors.onPrimary.withValues(alpha: Alpha.scrim), width: DS.s(2))),
        child: ClipOval(
          child: KitPhoto(url: cover, width: box, height: box, tone: TripCityArt.toneOf(cityKey), asset: TravelIcon.map, iconSize: 32),
        ),
      ),
    );
  }
}

class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.text, this.teal = false});

  final String text;
  final bool teal;

  @override
  Widget build(BuildContext context) => Container(
        padding: DS.sym(h: 10, v: 4),
        decoration: BoxDecoration(color: BuddyLook.note[teal ? NoteToneColor.teal : NoteToneColor.indigo]!.$1, borderRadius: DS.circular(12)),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w600, teal ? SocialLookB.seatsText : BuddyLook.indigoText, letterSpacing: 0)),
      );
}

class SocialPickChip extends StatelessWidget {
  const SocialPickChip({super.key, required this.label, required this.selected, required this.onTap, this.trailing});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    final fg = selected ? DesignColors.onPrimary : Ink3D.body;
    return Tap3D(
      onTap: onTap,
      label: label,
      selected: selected,
      exclude: true,
      child: Container(
        padding: DS.sym(h: 14, v: 8),
        decoration: BoxDecoration(
          gradient: selected ? tone.gradient : null,
          color: selected ? null : DesignColors.surface,
          borderRadius: DS.circular(20),
          border: selected ? null : Border.all(color: Form3D.outline, width: DS.s(1.5)),
          boxShadow: selected ? tone.glow(blur: 0, dy: 4) : DS.shadows(Form3D.cardShadow),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(14, FontWeight.w600, fg, letterSpacing: 0))),
            if (trailing != null) ...[Gap.h(5), Icon(trailing, size: DS.s(15), color: fg)],
          ],
        ),
      ),
    );
  }
}

class SmallLabel extends StatelessWidget {
  const SmallLabel({super.key, required this.text, this.padding, this.caps = false});

  final String text;
  final EdgeInsets? padding;
  final bool caps;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding ?? DS.gapInsets(l: 22, t: 20, r: 22, b: 10),
        child: caps
            ? Text(text.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w700, Ink3D.grey, letterSpacing: 0.8))
            : Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w600, Ink3D.sub, letterSpacing: 0)),
      );
}

class SafetyLine extends StatelessWidget {
  const SafetyLine({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: DS.gapInsets(l: 18, t: 18, r: 18),
        padding: DS.insets(l: 14, t: 12, r: 16, b: 12),
        decoration: BoxDecoration(color: ChatLook3D.bannerFill, borderRadius: DS.circular(16)),
        child: Row(
          children: [
            ExcludeSemantics(child: Art3D(asset: ListingArt.clipboard, size: 30, shadowBlur: 2, shadowOffset: const Offset(1, 2))),
            Gap.h(12),
            Expanded(child: Text(text, style: Ink3D.text(13.5, FontWeight.w400, ChatLook3D.bannerText, height: 1.45, letterSpacing: 0))),
          ],
        ),
      );
}
