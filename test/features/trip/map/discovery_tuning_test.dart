import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/map/discovery_ids.dart';
import 'package:bakhli/features/trip/map/trip_discovery_layer.dart';
import 'package:bakhli/features/trip/map/trip_marker_images.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

// Bug 3 (2026-11-24): one zoom-following size set for trip and stay; final dp under the approved DS scale.
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

  test('approved scale: zoom 10 / 14 / 17 = photo 44 / 60 / 72, badge 30 / 40 / 48, dot 18 / 28 / 34, selected 26 / 36 / 43', () {
    DS.applyApproved();
    for (final t in [DiscTuning.trip, DiscTuning.stay]) {
      near(stops(t.photoIconSize).map((f) => f * t.photoDp).toList(), [44, 60, 72]);
      near(stops(t.badgeIconSize).map((f) => f * t.badgeDp).toList(), [30, 40, 48]);
      near(stops(t.dotRadius(1)).map((r) => (r + 1) * 2).toList(), [18, 28, 34]);
      near(stops(t.selDotRadius(2)).map((r) => (r + 2) * 2).toList(), [26, 36, 43]);
      expect(t.hitDp, 44);
    }
    expect(DiscTuning.trip.photoMax, 40);
    expect(DiscTuning.stay.photoMax, 24);
  });

  test('markers are drawn at the zoomed-in size, so the zoom only scales them down', () {
    DS.applyApproved();
    final t = DiscTuning.trip;
    expect(t.photoDp, closeTo(72, 1e-9));
    expect(t.badgeDp, closeTo(48, 1e-9));
    for (final f in [...stops(t.photoIconSize), ...stops(t.badgeIconSize)]) {
      expect(f, lessThanOrEqualTo(1.0));
    }
  });

  test('selected icon and halo grow with the zoom too', () {
    DS.applyApproved();
    final t = DiscTuning.trip;
    final sel = (t.selIconSize(DiscPaint.selIconScale) as List);
    expect((sel[6] as double) * t.photoDp, closeTo(72, 1e-9), reason: 'normal zoom: photo and badge share one scale');
    expect((sel[6] as double) * t.badgeDp, closeTo(48, 1e-9));
    final out = sel[4] as List;
    expect(out.take(3).toList(), ['match', ['get', 'kind'], 'badge']);
    expect((out[3] as double) * t.badgeDp, closeTo(36, 1e-9));
    expect((out[4] as double) * t.photoDp, closeTo(52.8, 1e-9));
    final halo = t.haloRadius('dot', DiscPaint.selIconScale) as List;
    final small = halo[4] as List, full = halo[8] as List;
    expect(full[3], closeTo(t.haloDotDp / 2, 1e-9));
    expect(full[4], closeTo(t.haloPhotoDp / 2, 1e-9));
    expect(small[3] as double, lessThan(full[3] as double));
    expect((small[4] as double) * 2, greaterThan(44 * DiscPaint.selIconScale));
  });

  test('a tuning without zoom sizes keeps plain numbers', () {
    DS.applyApproved();
    final t = DiscTuning(photoMax: 40, photoDp: DS.s(54));
    expect(t.photoIconSize, 1.0);
    expect(t.badgeIconSize, 1.0);
    expect(t.dotRadius(1), t.dotDp / 2 - 1);
    expect(t.selIconSize(DiscPaint.selIconScale), DiscPaint.selIconScale);
  });

  test('the trip and stay layers paint with the zoom expressions', () {
    DS.debugReset();
    for (final s in [DiscTuning.trip, DiscTuning.stay]) {
      final specs = {for (final x in DiscLayers.specs(s)) x.id: x};
      final dots = DiscPaint.of(specs[DiscIds.layerDots]!, s) as CircleLayerProperties;
      final photo = DiscPaint.of(specs[DiscIds.layerPhoto]!, s) as SymbolLayerProperties;
      final badge = DiscPaint.of(specs[DiscIds.layerBadge]!, s) as SymbolLayerProperties;
      final selDot = DiscPaint.of(specs[DiscIds.layerSelDot]!, s) as CircleLayerProperties;
      final selIcon = DiscPaint.of(specs[DiscIds.layerSelIcon]!, s) as SymbolLayerProperties;
      final halo = DiscPaint.of(specs[DiscIds.layerSelHalo]!, s) as CircleLayerProperties;
      expect(dots.circleRadius, s.dotRadius(1));
      expect(photo.iconSize, s.photoIconSize);
      expect(badge.iconSize, s.badgeIconSize);
      expect(selDot.circleRadius, s.selDotRadius(2));
      expect(selIcon.iconSize, s.selIconSize(DiscPaint.selIconScale));
      expect(halo.circleRadius, s.haloRadius('dot', DiscPaint.selIconScale));
    }
  });

  test('the photo marker disk cache key follows the marker size, so old PNGs of another size are not reused', () {
    DS.debugReset();
    final raw = TripMarkerImages.cacheKey('w/12', 'https://a/x.jpg', DiscTuning.trip);
    DS.applyApproved();
    final scaled = TripMarkerImages.cacheKey('w/12', 'https://a/x.jpg', DiscTuning.trip);
    expect(scaled, isNot(raw));
    expect(scaled, startsWith('w_12_72_'));
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
