import 'dart:math' as math;

import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/utils/spot_photo_url.dart';
import 'package:flutter/material.dart';

import '../map/discovery_api.dart';
import '../models/trip_spot_category.dart';
import '../trip_strings_map_disc.dart';
import 'trip_spot_row.dart';

enum TripMapCardButton { primary, white, danger }

class TripMapSpotCard extends StatelessWidget {
  final DiscoverySpot spot;
  final DiscoveryMode mode;
  final int? plannedDay;
  final int? targetDay;
  final String? line;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  final VoidCallback? onDetails;
  final VoidCallback? onClose;
  final Color Function(int day)? dayColorOf;
  final double? tipX;
  final ListingTone? tone;

  static const double photo = 84;
  static const double artSize = 56;
  static const double maxWidth = 420;

  const TripMapSpotCard({
    super.key,
    required this.spot,
    required this.mode,
    this.plannedDay,
    this.targetDay,
    this.line,
    this.onAdd,
    this.onRemove,
    this.onDetails,
    this.onClose,
    this.dayColorOf,
    this.tipX,
    this.tone,
  });

  ListingTone get _tone => tone ?? ListingTone.indigo;

  bool get _planned => mode == DiscoveryMode.full && plannedDay != null;

  static TextStyle get titleStyle => Ink3D.text(15, FontWeight.w600, Ink3D.title, letterSpacing: 0, height: 1.3);
  static TextStyle get lineStyle => Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText, letterSpacing: 0);
  static TextStyle get categoryStyle => TypeTokens.style(11, FontWeight.w500, color: TypeTokens.secondary);

  List<Widget> _buttons() {
    final t = _tone;
    final details = _CardButton(key: const ValueKey('disc-card-details'), kind: TripMapCardButton.white, tone: t, label: TripMapDiscStrings.details, onTap: onDetails);
    if (mode == DiscoveryMode.readOnly) return [details];
    if (_planned) {
      return [details, _CardButton(key: const ValueKey('disc-card-remove'), kind: TripMapCardButton.danger, tone: t, label: TripMapDiscStrings.removeFromDay, onTap: onRemove)];
    }
    final day = targetDay;
    if (day == null) return [details];
    return [
      _CardButton(
        key: const ValueKey('disc-card-add'),
        kind: TripMapCardButton.primary,
        tone: t,
        label: TripMapDiscStrings.addToDay(day),
        onTap: onAdd,
      ),
      details,
    ];
  }

  Widget _head() {
    final day = plannedDay;
    if (_planned && day != null) {
      final c = dayColorOf?.call(day) ?? ListingPalette.indigo.text;
      return Container(
        key: const ValueKey('disc-card-inday'),
        padding: DS.sym(h: 9, v: 2),
        decoration: BoxDecoration(color: DesignColors.tint(c, Alpha.tint), borderRadius: DS.br(CardRadius.pill)),
        child: Text(TripMapDiscStrings.inDay(day), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(11, FontWeight.w600, c)),
      );
    }
    return Container(
      key: const ValueKey('disc-card-cat'),
      padding: DS.insets(l: 7.5, r: 10, t: 2, b: 2),
      decoration: BoxDecoration(color: _tone.tint, borderRadius: DS.br(CardRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: DS.s(8), height: DS.s(8), decoration: BoxDecoration(color: TripSpotCategory.colorOf(spot.category), shape: BoxShape.circle)),
          Gap.h(5.5),
          Flexible(child: Text(TripSpotCategory.label(spot.category), maxLines: 1, overflow: TextOverflow.ellipsis, style: categoryStyle)),
        ],
      ),
    );
  }

  static List<BoxShadow> get _mediaShadow =>
      DS.shadows([BoxShadow(color: Ink3D.title.withValues(alpha: Alpha.v22), offset: const Offset(1, 3.75), blurRadius: 7.5)]);

  Widget _media() {
    final asset = TripSpotLook.assetOf(spot.category);
    final side = DS.s(photo);
    if (!spot.hasThumb) {
      return Container(
        key: const ValueKey('disc-card-art'),
        width: side,
        height: side,
        alignment: Alignment.center,
        decoration: BoxDecoration(gradient: TripSpotLook.gradientOf(spot.category), borderRadius: DS.circular(14), boxShadow: _mediaShadow),
        child: Art3D(asset: asset, size: artSize),
      );
    }
    return SizedBox.square(
      dimension: side,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: DS.circular(14), boxShadow: _mediaShadow),
        child: ClipRRect(
          key: const ValueKey('disc-card-photo'),
          borderRadius: DS.circular(14),
          child: TripSpotMedia.photo(spot.thumbUrl, SpotPhotoSize.square, TripSpotMedia.fallbackArt(asset)),
        ),
      ),
    );
  }

  List<BoxShadow> get _cardShadow {
    final grey = TripLook.dayCardShadow.first;
    return DS.shadows([
      BoxShadow(color: _tone.haloBase.withValues(alpha: Alpha.v26), offset: const Offset(1.1, 4), blurRadius: 14),
      BoxShadow(color: grey.color.withValues(alpha: Alpha.v14), offset: grey.offset, blurRadius: grey.blurRadius),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final text = line?.trim() ?? '';
    final buttons = _buttons();
    final card = _card(text, buttons);
    final tip = tipX;
    if (tip == null) return card;
    return LayoutBuilder(builder: (context, c) {
      final size = DS.s(16);
      final hi = c.maxWidth.isFinite ? math.max(DS.s(20), c.maxWidth - DS.s(36)) : tip;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            key: const ValueKey('disc-card-tip'),
            bottom: -DS.s(7),
            left: tip.clamp(DS.s(20), hi) - size / 2,
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(3), boxShadow: DS.shadows(TripLook.dayCardShadow)),
              ),
            ),
          ),
          card,
        ],
      );
    });
  }

  Widget _card(String text, List<Widget> buttons) {
    return Container(
      key: const ValueKey('disc-card'),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(20), boxShadow: _cardShadow),
      child: Stack(
        children: [
          Padding(
            padding: DS.insets(l: 10, t: 10, r: 10, b: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _media(),
                    Gap.h(12.5),
                    Expanded(
                      child: Padding(
                        padding: DS.insets(r: 30, t: 2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _head(),
                            Gap.v(4),
                            Text(spot.name, key: const ValueKey('disc-card-title'), maxLines: 2, overflow: TextOverflow.ellipsis, style: titleStyle),
                            if (text.isNotEmpty) ...[
                              Gap.v(2),
                              Text(text, key: const ValueKey('disc-card-line'), maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false, style: lineStyle),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Gap.v(14),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < buttons.length; i++) ...[if (i > 0) Gap.h(10), Expanded(child: buttons[i])],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: DS.s(8),
            top: DS.s(8),
            child: Tap3D(
              key: const ValueKey('disc-card-close'),
              onTap: onClose,
              label: TripMapDiscStrings.semClose,
              exclude: true,
              child: Container(
                key: const ValueKey('disc-card-close-dot'),
                width: DS.s(26),
                height: DS.s(26),
                decoration: BoxDecoration(color: _tone.tint, shape: BoxShape.circle),
                child: Icon(Icons.keyboard_arrow_down_rounded, size: DS.s(18), color: _tone.text),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  final TripMapCardButton kind;
  final ListingTone tone;
  final String label;
  final VoidCallback? onTap;

  const _CardButton({super.key, required this.kind, required this.tone, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = kind == TripMapCardButton.primary;
    final fg = switch (kind) {
      TripMapCardButton.primary => DesignColors.surface,
      TripMapCardButton.white => tone.text,
      TripMapCardButton.danger => Form3D.errorText,
    };
    final live = onTap != null;
    final body = ConstrainedBox(
      constraints: BoxConstraints(minHeight: DS.s(KitMetrics.touch)),
      child: DecoratedBox(
        key: const ValueKey('disc-card-btn-face'),
        decoration: BoxDecoration(
          color: primary ? null : DesignColors.surface,
          gradient: primary ? tone.gradient : null,
          borderRadius: DS.br(CardRadius.pill),
          boxShadow: primary ? (live ? tone.glow() : null) : DS.shadows(Ink3D.softShadow),
        ),
        child: Padding(
          padding: DS.sym(h: 8, v: 6),
          child: Center(
            widthFactor: 1,
            child: Text(label, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: Ink3D.text(13, FontWeight.w700, fg)),
          ),
        ),
      ),
    );
    return Tap3D(
      onTap: onTap,
      label: label,
      exclude: true,
      child: live ? body : Opacity(opacity: Alpha.v45, child: body),
    );
  }
}
