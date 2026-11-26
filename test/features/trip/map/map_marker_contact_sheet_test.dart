import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/buddy/viewer/widgets/viewer_map_scene.dart';
import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:bakhli/features/trip/map/map_marker_sizes.dart';
import 'package:bakhli/features/trip/map/trip_marker_images.dart';
import 'package:bakhli/features/trip/map/trip_route_stops.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _zooms = [DiscTuning.zoomOut, DiscTuning.zoomMid, DiscTuning.zoomIn];
const _phone = 360.0;

// Run with MAP_SHEET_OUT=<png path> to write the contact sheet: one 360 dp phone outline per zoom column (10 / 14 / 17),
// rows top to bottom: new stop, old stop, new photo, old photo, new badge, old badge, new dot, old dot, viewer stop.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('contact sheet: new stop, photo, badge, dot and viewer stop at zoom 10 / 14 / 17 against the previous sizes', (tester) async {
    await tester.runAsync(() async {
      DS.applyApproved();
      addTearDown(DS.debugReset);
      const painter = CanvasMarkerPainter();
      const ring = Color(0xFFFF8A3D);
      final trip = DiscTuning.trip, stops = DiscTuning.tripStops, viewer = ViewerMapScene.tuning;
      final oldT = DiscTuning(
        photoMax: 40,
        photoDp: DS.s(MapMarkerSizes.photoFull),
        photoMidDp: DS.s(MapMarkerSizes.photoMid),
        photoMinDp: DS.s(MapMarkerSizes.photoMin),
        badgeDp: DS.s(MapMarkerSizes.badgeFull),
        badgeMidDp: DS.s(MapMarkerSizes.badgeMid),
        badgeMinDp: DS.s(MapMarkerSizes.badgeMin),
        dotDp: DS.s(MapMarkerSizes.dotFull),
        dotMidDp: DS.s(MapMarkerSizes.dotMid),
        dotMinDp: DS.s(MapMarkerSizes.dotMin),
        stopBadgeDp: DS.s(MapMarkerSizes.stopBadge),
      );
      final thumb = await _solid(120, 96, const Color(0xFF3366CC));
      final newPhoto = await painter.photo(thumb, trip);
      final oldPhoto = await painter.photo(thumb, oldT);
      expect(newPhoto, isNotNull);
      expect(oldPhoto, isNotNull);

      final rows = <(ui.Image, List<double>)>[
        (await _image(await painter.stop(category: 'temple', ring: ring, number: 2, t: stops)), _factors(TripRouteStops().iconSize)),
        (await _image(await painter.stop(category: 'temple', ring: ring, number: 2, t: oldT)), _factors(TripRouteStops(tuning: oldT).iconSize)),
        (await _image(newPhoto!), _factors(trip.photoIconSize)),
        (await _image(oldPhoto!), _factors(oldT.photoIconSize)),
        (await _image(await painter.badge('lake', trip)), _factors(trip.badgeIconSize)),
        (await _image(await painter.badge('lake', oldT)), _factors(oldT.badgeIconSize)),
        (await _image(await painter.dot(TripTokens.spotWater, trip)), _factors(trip.dotIconSize)),
        (await _image(await painter.dot(TripTokens.spotWater, oldT)), _factors(oldT.dotIconSize)),
        (await _image(await painter.stop(category: 'temple', ring: ring, number: 2, t: viewer)), _factors(TripRouteStops(tuning: viewer).iconSize)),
      ];
      expect(rows.first.$2, [closeTo(55 / 90, 1e-9), closeTo(75 / 90, 1e-9), closeTo(1, 1e-9)]);
      expect(rows.last.$2, [closeTo(1, 1e-9), closeTo(1, 1e-9), closeTo(1, 1e-9)], reason: 'the viewer stop is flat at the zoom-14 size');
      for (final (img, f) in rows) {
        expect(img.width * f.last, lessThanOrEqualTo(_phone), reason: 'every marker fits the 360 dp phone at zoom 17');
      }

      const gap = 40.0, pad = 16.0;
      final rowH = [for (final r in rows) r.$1.height * r.$2.reduce(max)];
      final height = rowH.fold(0.0, (a, h) => a + h + pad) + pad * 3;
      final width = gap + _zooms.length * (_phone + gap);
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = const Color(0xFFEFEFEF));
      for (var c = 0; c < _zooms.length; c++) {
        final x = gap + c * (_phone + gap);
        final frame = RRect.fromRectAndRadius(Rect.fromLTWH(x, pad, _phone, height - pad * 2), const Radius.circular(24));
        canvas.drawRRect(frame, Paint()..color = const Color(0xFFFFFFFF));
        canvas.drawRRect(
          frame,
          Paint()
            ..color = const Color(0xFF333333)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        var y = pad * 2;
        for (var r = 0; r < rows.length; r++) {
          final (img, f) = rows[r];
          final w = img.width * f[c], h = img.height * f[c];
          canvas.drawImageRect(
            img,
            Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
            Rect.fromLTWH(x + (_phone - w) / 2, y + (rowH[r] - h) / 2, w, h),
            Paint()..filterQuality = FilterQuality.high,
          );
          y += rowH[r] + pad;
        }
      }
      final sheet = await rec.endRecording().toImage(width.round(), height.round());
      final bytes = (await sheet.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      expect(bytes.length, greaterThan(100));
      expect(MapMarkerSizes.scale, closeTo(3.45, 1e-9));
      final out = Platform.environment['MAP_SHEET_OUT'];
      if (out != null && out.isNotEmpty) File(out).writeAsBytesSync(bytes);
    });
  });
}

Future<ui.Image> _image(Uint8List png) async => (await (await ui.instantiateImageCodec(png)).getNextFrame()).image;

Future<Uint8List> _solid(int w, int h, Color c) async {
  final r = ui.PictureRecorder();
  Canvas(r).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = c);
  final img = await r.endRecording().toImage(w, h);
  return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

// Evaluates a MapLibre zoom-interpolated icon size (or a plain number) at the three sheet zooms.
List<double> _factors(Object size) => [for (final z in _zooms) _at(size, z)];

double _at(Object size, double zoom) {
  if (size is num) return size.toDouble();
  final e = size as List;
  final z = [for (var i = 3; i < e.length; i += 2) (e[i] as num).toDouble()];
  final v = [for (var i = 4; i < e.length; i += 2) (e[i] as num).toDouble()];
  if (zoom <= z.first) return v.first;
  for (var i = 1; i < z.length; i++) {
    if (zoom <= z[i]) return v[i - 1] + (v[i] - v[i - 1]) * (zoom - z[i - 1]) / (z[i] - z[i - 1]);
  }
  return v.last;
}
