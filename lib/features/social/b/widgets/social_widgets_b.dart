import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../design/design.dart';
import '../../../../design/extra/ext_chat.dart';
import '../../../buddy/shared/buddy_look.dart';
import '../../../trip/data/trip_city_catalog.dart';
import '../../../trip/models/trip_city_model.dart';
import '../../../trip/widgets/hub/hub_art.dart';
import '../../../trip/widgets/trip_city_art.dart';
import '../../shared/social_models.dart';
import '../social_strings_b.dart';

abstract final class SocialLookB {
  static const Color seatsText = BuddyLook.tealEnd;

  // Corner rule: cards with a top-right control (feed card menu/follow, Post pill, list radios) stay uniform; inner covers and
  // mid cards use the tile notch; the big trip cover uses the hero notch.
  static BorderRadius get cardRadius => DS.br(CardRadius.card);

  static BorderRadius get tileRadius => DS.br(CardRadius.tile);

  static BorderRadius get coverRadius => DS.br(CardRadius.tile);

  static BorderRadius get heroRadius => DS.br(CardRadius.hero);

  static const List<String> arts = [ListingArt.mountain, ListingArt.canoe, ListingArt.camping, ListingArt.sunriseMountains];
  static final List<ListingTone> _tones = [ListingTone.indigo, ListingTone.coral, ListingTone.teal, ListingTone.cB];

  static int seedOf(int cityKey, String fallback) => cityKey != 0 ? cityKey.abs() : fallback.hashCode.abs();

  static ListingTone toneOf(int seed) => _tones[seed % _tones.length];

  static String artOf(int seed) => arts[seed % arts.length];

  static const String _trainArt = 'assets/images/design/travel3d/train.png';

  static const Map<String, String> _travelArt = {
    TravelModes.taxi: ListingArt.taxi,
    TravelModes.bike: HubArt.motorcycle,
    TravelModes.bus: ListingArt.bus,
    TravelModes.train: _trainArt,
  };

  static String? travelArtOf(String? code) => _travelArt[code];
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

  static final RxInt loaded = 0.obs;
  static Future<void>? _pending;
  static DateTime? _failedAt;
  static Object? _seenKey;

  // Cards can build before any trip screen loaded the city catalog; fetch it once and redraw the covers.
  static void ensure() {
    final catalog = TripCityCatalog.to..warmFromDisk();
    final data = catalog.dataKey;
    if (data != null) {
      if (!identical(data, _seenKey)) {
        _seenKey = data;
        loaded.value++;
      }
      return;
    }
    if (_pending != null) return;
    final failed = _failedAt;
    if (failed != null && DateTime.now().difference(failed) < const Duration(seconds: 60)) return;
    _pending = catalog.load().then<void>((_) {
      _failedAt = null;
      _seenKey = catalog.dataKey;
      loaded.value++;
    }, onError: (Object _) {
      _failedAt = DateTime.now();
    }).whenComplete(() => _pending = null);
  }

  @visibleForTesting
  static void debugReset() {
    _pending = null;
    _failedAt = null;
    _seenKey = null;
    _key = null;
    _byKey = const {};
  }
}

class CityCover extends StatefulWidget {
  const CityCover({super.key, required this.cityKey, required this.builder});

  final int cityKey;
  final Widget Function(String? cover) builder;

  @override
  State<CityCover> createState() => _CityCoverState();
}

class _CityCoverState extends State<CityCover> {
  @override
  void initState() {
    super.initState();
    if (widget.cityKey != 0) CityCoverLookup.ensure();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        CityCoverLookup.loaded.value;
        return widget.builder(CityCoverLookup.cover(widget.cityKey));
      });
}

class TripCoverArt extends StatelessWidget {
  const TripCoverArt({super.key, required this.cityKey, required this.seed, required this.size});

  final int cityKey;
  final int seed;
  final double size;

  @override
  Widget build(BuildContext context) => CityCover(cityKey: cityKey, builder: _art);

  Widget _art(String? cover) {
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

class TravelModeChip extends StatelessWidget {
  const TravelModeChip({super.key, required this.code});

  final String code;

  static const double artSize = 16;

  @override
  Widget build(BuildContext context) {
    final label = SocialStringsB.travelLabel(code);
    final art = SocialLookB.travelArtOf(code);
    if (label == null || art == null) return const SizedBox.shrink();
    return Container(
      padding: DS.sym(h: 10, v: 4),
      decoration: BoxDecoration(color: BuddyLook.note[NoteToneColor.indigo]!.$1, borderRadius: DS.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Art3D(asset: art, size: artSize, shadowBlur: 1, shadowOffset: const Offset(0.5, 1))),
          Gap.h(5),
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w600, BuddyLook.indigoText, letterSpacing: 0))),
        ],
      ),
    );
  }
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

// D10b: a radio ring on unselected rows, the SheetListRow check when selected.
class RadioMark extends StatelessWidget {
  const RadioMark({super.key, required this.selected, required this.tone});

  final bool selected;
  final ListingTone tone;

  @override
  Widget build(BuildContext context) => Container(
        width: DS.s(28),
        height: DS.s(28),
        decoration: selected
            ? BoxDecoration(shape: BoxShape.circle, gradient: tone.gradient, boxShadow: tone.glow(dy: 3, blur: 6))
            : BoxDecoration(shape: BoxShape.circle, border: Border.all(color: BuddyLook.checkOff, width: DS.s(2))),
        child: selected ? Icon(Icons.check_rounded, size: DS.s(17), color: DesignColors.onPrimary) : null,
      );
}
