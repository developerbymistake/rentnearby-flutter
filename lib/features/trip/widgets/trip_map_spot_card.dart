import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:bakhli/utils/spot_photo_url.dart';
import 'package:flutter/material.dart';

import '../map/discovery_api.dart';
import '../models/trip_spot_category.dart';
import '../trip_strings_map_disc.dart';
import 'trip_spot_row.dart';

enum TripMapCardButton { primary, soft, danger }

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

  static const double photo = 84;

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
  });

  bool get _planned => mode == DiscoveryMode.full && plannedDay != null;

  static TextStyle get titleStyle => Ink3D.text(14, FontWeight.w600, Ink3D.title, letterSpacing: 0, height: 1.3);
  static TextStyle get lineStyle => Ink3D.text(12.5, FontWeight.w400, TripLook.mutedText, letterSpacing: 0);

  List<Widget> _buttons() {
    final details = _CardButton(key: const ValueKey('disc-card-details'), kind: TripMapCardButton.soft, label: TripMapDiscStrings.details, onTap: onDetails);
    if (mode == DiscoveryMode.readOnly) return [details];
    if (_planned) {
      return [details, _CardButton(key: const ValueKey('disc-card-remove'), kind: TripMapCardButton.danger, label: TripMapDiscStrings.removeFromDay, onTap: onRemove)];
    }
    final day = targetDay;
    return [
      _CardButton(
        key: const ValueKey('disc-card-add'),
        kind: TripMapCardButton.primary,
        label: TripMapDiscStrings.addToDay(day ?? 1),
        onTap: day == null ? null : onAdd,
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
        child: Text(TripMapDiscStrings.inDay(day), maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w600, c)),
      );
    }
    return Row(
      key: const ValueKey('disc-card-cat'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: DS.s(8), height: DS.s(8), decoration: BoxDecoration(color: TripSpotCategory.colorOf(spot.category), shape: BoxShape.circle)),
        Gap.h(5),
        Flexible(child: Text(TripSpotCategory.label(spot.category), maxLines: 1, overflow: TextOverflow.ellipsis, style: lineStyle)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = line?.trim() ?? '';
    final buttons = _buttons();
    return Container(
      key: const ValueKey('disc-card'),
      decoration: BoxDecoration(color: DesignColors.surface, borderRadius: DS.circular(20), boxShadow: DS.shadows(TripLook.dayCardShadow)),
      child: Stack(
        children: [
          Padding(
            padding: DS.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (spot.hasThumb) ...[
                      ClipRRect(
                        key: const ValueKey('disc-card-photo'),
                        borderRadius: DS.circular(14),
                        child: SizedBox.square(
                          dimension: DS.s(photo),
                          child: TripSpotMedia.photo(spot.thumbUrl, SpotPhotoSize.square, TripSpotMedia.fallbackArt(TripSpotLook.assetOf(spot.category))),
                        ),
                      ),
                      Gap.h(10),
                    ],
                    Expanded(
                      child: Padding(
                        padding: DS.insets(r: 28, t: 2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _head(),
                            Gap.v(3),
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
                Gap.v(10),
                Row(
                  children: [
                    for (var i = 0; i < buttons.length; i++) ...[if (i > 0) Gap.h(8), Expanded(child: buttons[i])],
                  ],
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
                width: DS.s(26),
                height: DS.s(26),
                decoration: const BoxDecoration(color: Form3D.fill, shape: BoxShape.circle),
                child: Icon(Icons.keyboard_arrow_down_rounded, size: DS.s(18), color: Ink3D.grey),
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
  final String label;
  final VoidCallback? onTap;

  const _CardButton({super.key, required this.kind, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = ListingTone.indigo;
    final (Color? fill, Color fg, Border? border) = switch (kind) {
      TripMapCardButton.primary => (null, DesignColors.surface, null),
      TripMapCardButton.soft => (ListingPalette.indigo.button, ListingPalette.indigo.text, null),
      TripMapCardButton.danger => (ListingPalette.coral.tint, ListingPalette.coral.text, Border.all(color: ListingPalette.coral.line, width: DS.s(1))),
    };
    final live = onTap != null;
    final body = ConstrainedBox(
      constraints: BoxConstraints(minHeight: DS.s(40)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          gradient: kind == TripMapCardButton.primary ? tone.gradient : null,
          border: border,
          borderRadius: DS.br(CardRadius.pill),
          boxShadow: kind == TripMapCardButton.primary && live ? tone.glow() : null,
        ),
        child: Padding(
          padding: DS.sym(h: 8, v: 6),
          child: Center(
            widthFactor: 1,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1, softWrap: false, style: Ink3D.text(13, FontWeight.w700, fg)),
            ),
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
