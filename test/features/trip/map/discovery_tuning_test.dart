import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/map/discovery_ids.dart';
import 'package:bakhli/features/trip/map/trip_discovery_layer.dart';
import 'package:bakhli/features/trip/map/trip_marker_images.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

// Owner order 2026-11-25: spot markers 3x the 2026-11-24 sizes; final dp under the approved DS scale.
void main() {
  final restore = (size: DS.size, font: DS.font, gap: DS.gapRel, floor: DS.fontFloor);
  tearDown(() => DS.debugSet(size: restore.size, font: restore.font, gapRel: restore.gap, fontFloor: restore.floor));

  List<double> stops(Object e) {
    final l = e as List;
    expect(l.take(3).toList(), ['interpolate', ['linear'], ['zoom']]);
    expect([l[3], l[5], l[7]], [DiscTuning.zoomOut, DiscTuning.zoomMid, DiscTuning.zoomIn]);
    return [l[4] as double, l[6] as double, l[8] as double];
  }

  void near(List<double> got, List<double> want) {
    for (var i = 0; i < want.length; i++) {
      expect(got[i], closeTo(want[i], 1e-9));
    }
  }

  test('approved scale: zoom 10 / 14 / 17 = photo 132 / 180 / 216, badge 90 / 120 / 144, dot 54 / 84 / 102, selected 78 / 108 / 129', () {
    DS.applyApproved();
    for (final t in [DiscTuning.trip, DiscTuning.stay]) {
      near(stops(t.photoIconSize).map((f) => f * t.photoDp).toList(), [132, 180, 216]);
      near(stops(t.badgeIconSize).map((f) => f * t.badgeDp).toList(), [90, 120, 144]);
      near(stops(t.dotRadius(1)).map((r) => (r + 1) * 2).toList(), [54, 84, 102]);
      near(stops(t.selDotRadius(2)).map((r) => (r + 2) * 2).toList(), [78, 108, 129]);
      expect(t.hitDp, 44);
    }
    expect(DiscTuning.trip.photoMax, 40);
    expect(DiscTuning.stay.photoMax, 24);
  });

  test('markers are drawn at the zoomed-in size, so the zoom only scales them down', () {
    DS.applyApproved();
    final t = DiscTuning.trip;
    expect(t.photoDp, closeTo(216, 1e-9));
    expect(t.badgeDp, closeTo(144, 1e-9));
    for (final f in [...stops(t.photoIconSize), ...stops(t.badgeIconSize)]) {
      expect(f, lessThanOrEqualTo(1.0));
    }
  });

  test('selected icon and halo grow with the zoom too', () {
    DS.applyApproved();
    final t = DiscTuning.trip;
    final sel = (t.selIconSize(DiscPaint.selIconScale) as List);
    expect((sel[6] as double) * t.photoDp, closeTo(216, 1e-9), reason: 'normal zoom: photo and badge share one scale');
    expect((sel[6] as double) * t.badgeDp, closeTo(144, 1e-9));
    final out = sel[4] as List;
    expect(out.take(3).toList(), ['match', ['get', 'kind'], 'badge']);
    expect((out[3] as double) * t.badgeDp, closeTo(108, 1e-9));
    expect((out[4] as double) * t.photoDp, closeTo(158.4, 1e-9));
    final halo = t.haloRadius('dot', DiscPaint.selIconScale) as List;
    final small = halo[4] as List, full = halo[8] as List;
    expect(full[3], closeTo(t.haloDotDp / 2, 1e-9));
    expect(full[4], closeTo(t.haloPhotoDp / 2, 1e-9));
    expect(small[3] as double, lessThan(full[3] as double));
    expect((small[4] as double) * 2, greaterThan(44 * DiscPaint.selIconScale));
  });

  test('3x of the 2026-11-24 sizes in every marker field, halo too; route stops and the tap box unchanged', () {
    DS.applyApproved();
    const head = (photo: 72.0, badge: 48.0, dot: 34.0, selDot: 43.0, haloPhoto: 101.6, haloDot: 60.8, photoMin: 44.0, dotMin: 18.0);
    for (final t in [DiscTuning.trip, DiscTuning.stay]) {
      expect(t.photoDp, closeTo(head.photo * DiscTuning.markerScale, 1e-9));
      expect(t.badgeDp, closeTo(head.badge * DiscTuning.markerScale, 1e-9));
      expect(t.dotDp, closeTo(head.dot * DiscTuning.markerScale, 1e-9));
      expect(t.selDotDp, closeTo(head.selDot * DiscTuning.markerScale, 1e-9));
      expect(t.haloPhotoDp, closeTo(head.haloPhoto * DiscTuning.markerScale, 1e-9));
      expect(t.haloDotDp, closeTo(head.haloDot * DiscTuning.markerScale, 1e-9));
      expect(t.photoMinDp!, closeTo(head.photoMin * DiscTuning.markerScale, 1e-9));
      expect(t.dotMinDp!, closeTo(head.dotMin * DiscTuning.markerScale, 1e-9));
      expect(t.hitDp, greaterThanOrEqualTo(44));
    }
    final stops = DiscTuning.tripStops;
    expect(stops.photoDp, closeTo(head.photo, 1e-9));
    expect(stops.photoMinDp!, closeTo(head.photoMin, 1e-9));
    expect(stops.stopBadgeDp!, closeTo(43.2, 1e-9));
  });

  test('big markers declutter: every non-photo spot has a badge, badges and dots collide by rank, dots from zoom 12', () {
    DS.debugReset();
    for (final t in [DiscTuning.trip, DiscTuning.stay]) {
      expect(t.badgeMax, greaterThanOrEqualTo(DiscTuning.packMax));
      final specs = {for (final x in DiscLayers.specs(t)) x.id: x};
      expect(specs[DiscIds.layerBadge]!.minZoom, isNull);
      expect(specs[DiscIds.layerDots]!.minZoom, DiscTuning.dotsFromZoom);
      expect(specs[DiscIds.layerDots]!.kind, DiscLayerKind.symbol);
      final dots = DiscPaint.of(specs[DiscIds.layerDots]!, t) as SymbolLayerProperties;
      expect(dots.iconImage, DiscLayers.iconImageDot);
      expect(dots.iconAllowOverlap, isFalse);
      expect(dots.iconIgnorePlacement, isFalse);
      expect(dots.symbolSortKey, DiscLayers.sortKey);
      final badge = DiscPaint.of(specs[DiscIds.layerBadge]!, t) as SymbolLayerProperties;
      expect(badge.iconAllowOverlap, isFalse);
      expect(badge.symbolSortKey, DiscLayers.sortKey);
    }
    expect(DiscLayers.specs(DiscTuning(photoMax: 40, photoDp: 54))[1].minZoom, 12, reason: 'a custom tuning keeps the old badge zoom');
  });

  test('a tuning without zoom sizes keeps plain numbers', () {
    DS.applyApproved();
    final t = DiscTuning(photoMax: 40, photoDp: DS.s(54));
    expect(t.photoIconSize, 1.0);
    expect(t.dotIconSize, 1.0);
    expect(t.badgeIconSize, 1.0);
    expect(t.dotRadius(1), t.dotDp / 2 - 1);
    expect(t.selIconSize(DiscPaint.selIconScale), DiscPaint.selIconScale);
  });

  test('the trip and stay layers paint with the zoom expressions', () {
    DS.debugReset();
    for (final s in [DiscTuning.trip, DiscTuning.stay]) {
      final specs = {for (final x in DiscLayers.specs(s)) x.id: x};
      final dots = DiscPaint.of(specs[DiscIds.layerDots]!, s) as SymbolLayerProperties;
      final photo = DiscPaint.of(specs[DiscIds.layerPhoto]!, s) as SymbolLayerProperties;
      final badge = DiscPaint.of(specs[DiscIds.layerBadge]!, s) as SymbolLayerProperties;
      final selDot = DiscPaint.of(specs[DiscIds.layerSelDot]!, s) as CircleLayerProperties;
      final selIcon = DiscPaint.of(specs[DiscIds.layerSelIcon]!, s) as SymbolLayerProperties;
      final halo = DiscPaint.of(specs[DiscIds.layerSelHalo]!, s) as CircleLayerProperties;
      expect(dots.iconSize, s.dotIconSize);
      near(stops(s.dotIconSize).map((f) => f * s.dotDp).toList(), stops(s.dotRadius(1)).map((r) => (r + 1) * 2).toList());
      expect(photo.iconSize, s.photoIconSize);
      expect(badge.iconSize, s.badgeIconSize);
      expect(selDot.circleRadius, s.selDotRadius(2));
      expect(selIcon.iconSize, s.selIconSize(DiscPaint.selIconScale));
      expect(halo.circleRadius, s.haloRadius('dot', DiscPaint.selIconScale, plannedKind: 'planned'));
    }
  });

  test('the photo marker disk cache key follows the marker size, so old PNGs of another size are not reused', () {
    DS.debugReset();
    final raw = TripMarkerImages.cacheKey('w/12', 'https://a/x.jpg', DiscTuning.trip);
    DS.applyApproved();
    final scaled = TripMarkerImages.cacheKey('w/12', 'https://a/x.jpg', DiscTuning.trip);
    expect(scaled, isNot(raw));
    expect(scaled, startsWith('w_12_216_'));
  });

  testWidgets('compose: the trip photo marker canvas follows px(photoDp) under the approved scale', (tester) async {
    DS.applyApproved();
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 96, 96), Paint()..color = const Color(0xFF3366CC));
      final img = await recorder.endRecording().toImage(96, 96);
      final thumb = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final t = DiscTuning.trip;
      final png = (await const CanvasMarkerPainter().photo(Uint8List.fromList(thumb), t))!;
      final codec = await ui.instantiateImageCodec(png);
      final out = (await codec.getNextFrame()).image;
      expect(out.width, t.px(CanvasMarkerPainter.canvasDp(t.photoDp)));
    });
  });
}
