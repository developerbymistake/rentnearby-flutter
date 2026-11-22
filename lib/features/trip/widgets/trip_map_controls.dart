import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../trip_strings_map_disc.dart';

class TripMapControls extends StatelessWidget {
  final Axis axis;
  final double size;
  final Color glyph;
  final List<BoxShadow> shadow;
  final bool showEye;
  final bool eyeOn;
  final bool loading;
  final ValueChanged<bool>? onEye;
  final MapLibreMapController? Function()? map;
  final VoidCallback? onLocate;

  static const double columnSize = 44;
  static const double rowSize = 46;
  static const double columnGap = 10;
  static const double glyphSize = 22;

  TripMapControls.column({
    super.key,
    this.showEye = true,
    this.eyeOn = true,
    this.loading = false,
    this.onEye,
    this.map,
    this.onLocate,
  })  : axis = Axis.vertical,
        size = columnSize,
        glyph = ListingPalette.indigo.text,
        shadow = TripLook.cardShadowSoft;

  TripMapControls.row({
    super.key,
    this.showEye = true,
    this.eyeOn = true,
    this.loading = false,
    this.onEye,
    this.map,
    this.onLocate,
  })  : axis = Axis.horizontal,
        size = rowSize,
        glyph = ListingPalette.forest.g2,
        shadow = ShadowTokens.elev2;

  Future<void> _zoom(CameraUpdate update) async {
    final m = map?.call();
    if (m == null) return;
    try {
      await m.animateCamera(update);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      if (showEye)
        _MapCircle(
          key: const ValueKey('disc-eye'),
          size: size,
          shadow: shadow,
          label: eyeOn ? TripMapDiscStrings.semHidePlaces : TripMapDiscStrings.semShowPlaces,
          toggled: eyeOn,
          ring: loading ? glyph : null,
          onTap: onEye == null ? null : () => onEye!(!eyeOn),
          child: Icon(eyeOn ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: DS.s(glyphSize), color: eyeOn ? glyph : Ink3D.grey),
        ),
      _MapCircle(
        key: const ValueKey('disc-zoom-in'),
        size: size,
        shadow: shadow,
        label: TripMapDiscStrings.semZoomIn,
        onTap: () => _zoom(CameraUpdate.zoomIn()),
        child: Icon(Icons.add_rounded, size: DS.s(glyphSize), color: glyph),
      ),
      _MapCircle(
        key: const ValueKey('disc-zoom-out'),
        size: size,
        shadow: shadow,
        label: TripMapDiscStrings.semZoomOut,
        onTap: () => _zoom(CameraUpdate.zoomOut()),
        child: Icon(Icons.remove_rounded, size: DS.s(glyphSize), color: glyph),
      ),
      _MapCircle(
        key: const ValueKey('disc-locate'),
        size: size,
        shadow: shadow,
        label: TripMapDiscStrings.semLocate,
        onTap: onLocate,
        child: Icon(Icons.my_location_rounded, size: DS.s(glyphSize), color: glyph),
      ),
    ];
    if (axis == Axis.horizontal) {
      return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: buttons);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < buttons.length; i++) ...[if (i > 0) Gap.v(columnGap), buttons[i]],
      ],
    );
  }
}

class _MapCircle extends StatelessWidget {
  final double size;
  final List<BoxShadow> shadow;
  final String label;
  final bool? toggled;
  final Color? ring;
  final VoidCallback? onTap;
  final Widget child;

  const _MapCircle({super.key, required this.size, required this.shadow, required this.label, required this.onTap, required this.child, this.toggled, this.ring});

  @override
  Widget build(BuildContext context) {
    final d = DS.s(size);
    final ringColor = ring;
    return Tap3D(
      onTap: onTap,
      label: label,
      toggled: toggled,
      exclude: true,
      child: SizedBox(
        width: d,
        height: d,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: d,
              height: d,
              decoration: BoxDecoration(color: DesignColors.surface, shape: BoxShape.circle, boxShadow: DS.shadows(shadow)),
              alignment: Alignment.center,
              child: child,
            ),
            if (ringColor != null)
              SizedBox(
                width: d,
                height: d,
                child: CircularProgressIndicator(key: const ValueKey('disc-eye-ring'), strokeWidth: DS.s(2), color: ringColor),
              ),
          ],
        ),
      ),
    );
  }
}

class TripMapLoadingChip extends StatelessWidget {
  final String text;
  final bool loading;
  final ListingPalette palette;

  const TripMapLoadingChip({super.key, required this.text, this.loading = false, this.palette = ListingPalette.indigo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DS.sym(h: 12, v: 7),
      decoration: BoxDecoration(
        color: palette.tint,
        borderRadius: DS.br(CardRadius.pill),
        boxShadow: DS.shadows(TripLook.chipOffShadow),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading) ...[
            SizedBox.square(
              dimension: DS.s(12),
              child: CircularProgressIndicator(strokeWidth: DS.s(1.6), color: palette.text),
            ),
            Gap.h(6),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: FitnessAppTheme.fontName, fontSize: DS.f(11), fontWeight: FontWeight.w600, color: FitnessAppTheme.darkText),
            ),
          ),
        ],
      ),
    );
  }
}
