import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:bakhli/features/trip/map/trip_marker_images.dart';
import 'package:bakhli/features/trip/map/trip_route_stops.dart';
import 'package:bakhli/features/trip/models/trip_spot_category.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _ring = Color(0xFFFF8A3D);

DiscoverySpot _spot(String id, {String? thumb}) =>
    DiscoverySpot(id: id, lat: 30, lon: 78, category: 'temple', rank: 0, name: id, thumbUrl: thumb);

RouteStop _stop(int day, int index, int number) =>
    RouteStop(day: day, index: index, number: number, spot: _spot('s$number'), ring: _ring);

Future<Uint8List> _pngOf(int w, int h, Color c) async {
  final r = ui.PictureRecorder();
  Canvas(r).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = c);
  final img = await r.endRecording().toImage(w, h);
  return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

Future<({int w, ByteData bytes})> _raw(Uint8List png) async {
  final img = (await (await ui.instantiateImageCodec(png)).getNextFrame()).image;
  return (w: img.width, bytes: (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!);
}

List<int> _rgb(({int w, ByteData bytes}) r, double x, double y) {
  final o = (y.round() * r.w + x.round()) * 4;
  return [r.bytes.getUint8(o), r.bytes.getUint8(o + 1), r.bytes.getUint8(o + 2), r.bytes.getUint8(o + 3)];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stops are one GeoJSON point per stop with image, opacity and order', () {
    final stops = [_stop(1, 0, 1), _stop(1, 1, 2), _stop(2, 0, 3)];
    final g = TripRouteStops.geoJson(stops, [1, 1, 0.35]);
    final f = g['features'] as List;
    expect(f.length, 3);
    final last = f.last as Map;
    expect(last['id'], 2);
    expect((last['geometry'] as Map)['coordinates'], [78, 30]);
    expect(last['properties'], {'img': TripRouteStops.imageOf(2), 'op': 0.35, 'n': 3});
  });

  test('route stops keep the 2026-11-24 sizes: 44 / 60 / 72 dp at zoom 10 / 14 / 17', () {
    DS.applyApproved();
    addTearDown(DS.debugReset);
    final stops = TripRouteStops();
    final e = stops.iconSize as List;
    expect(e.take(3).toList(), [
      'interpolate',
      ['linear'],
      ['zoom'],
    ]);
    final t = DiscTuning.tripStops;
    expect(e[3], DiscTuning.zoomOut);
    expect((e[4] as double) * t.photoDp, closeTo(44, 1e-9));
    expect(e[5], DiscTuning.zoomMid);
    expect((e[6] as double) * t.photoDp, closeTo(60, 1e-9));
    expect(e[7], DiscTuning.zoomIn);
    expect(e[8], 1.0);
    expect(CanvasMarkerPainter.stopBadgeDp(t) * (e[6] as double), closeTo(36, 1e-9), reason: 'order badge about 36 dp at zoom 14');
    final number = CanvasMarkerPainter.stopNumberStyle(t);
    final caption = TypeTokens.caption;
    expect(number.fontSize! * (e[6] as double), closeTo(caption.fontSize!, 1e-9), reason: 'order number shows at caption size at zoom 14');
    expect(number.fontFamily, caption.fontFamily);
    expect(number.fontWeight, caption.fontWeight);
    expect(number.height, 1);
    final p = stops.layerProps.toJson();
    expect(p['icon-size'], e);
    expect(p['icon-opacity'], ['get', 'op']);
    expect(p['icon-allow-overlap'], isTrue);
  });

  test('stop marker paints the order number with the zoom-14 caption style', () {
    final src = File('lib/features/trip/map/trip_marker_images.dart').readAsStringSync();
    expect(src.contains("TextSpan(text: '\$number', style: stopNumberStyle(t))"), isTrue);
  });

  test('an unknown feature id gives no stop', () {
    final s = TripRouteStops();
    expect(s.at('0'), isNull);
    expect(s.at(null), isNull);
  });

  testWidgets('stop marker: photo in the white ring, day colour ring outside, badge on the corner', (tester) async {
    await tester.runAsync(() async {
      const painter = CanvasMarkerPainter();
      final t = DiscTuning.tripStops;
      final png = await painter.stop(thumb: await _pngOf(96, 120, const Color(0xFF3366CC)), category: 'temple', ring: _ring, number: 3, t: t);
      final r = await _raw(png);
      final side = t.px(CanvasMarkerPainter.stopCanvasDp(t));
      expect(r.w, side);
      final c = side / 2;
      final rad = t.photoDp / 2;
      expect(_rgb(r, c, c)[2], greaterThan(150), reason: 'photo inside');
      final white = _rgb(r, c - rad + 1, c);
      expect(white[0], greaterThan(200));
      expect(white[2], greaterThan(200));
      final ring = _rgb(r, c - rad - CanvasMarkerPainter.stopRingDp() / 2, c);
      expect(ring[0], greaterThan(200), reason: 'route ring outside the white ring');
      expect(ring[2], lessThan(120));
      final outer = rad + CanvasMarkerPainter.stopRingDp();
      final badge = Offset(c + outer * 0.7071, c - outer * 0.7071);
      final b = CanvasMarkerPainter.stopBadgeDp(t) / 2;
      final column = [for (var dy = -b; dy <= -1; dy++) _rgb(r, badge.dx, badge.dy + dy)];
      expect(column.any((p) => p[0] > 200 && p[2] < 120), isTrue, reason: 'badge filled with the route colour');
      expect(_rgb(r, 0, side - 1.0)[3], 0, reason: 'transparent corner');
    });
  });

  testWidgets('stop marker without a photo shows the category colour', (tester) async {
    await tester.runAsync(() async {
      const painter = CanvasMarkerPainter();
      final t = DiscTuning.tripStops;
      final r = await _raw(await painter.stop(category: 'temple', ring: _ring, number: 1, t: t));
      final c = t.px(CanvasMarkerPainter.stopCanvasDp(t)) / 2;
      final inner = t.photoDp / 2 - 2;
      final px = _rgb(r, c, c + inner * 0.85);
      final want = TripSpotCategory.colorOf('temple');
      expect((px[0] - (want.r * 255).round()).abs(), lessThan(12));
      expect((px[2] - (want.b * 255).round()).abs(), lessThan(12));
      final bad = await painter.stop(thumb: Uint8List.fromList([1, 2, 3]), category: 'temple', ring: _ring, number: 1, t: t);
      expect(await painter.valid(bad), isTrue, reason: 'a broken photo falls back to the icon');
    });
  });

  test('trip map draws real spot stops instead of fixed numbered circles', () {
    final src = File('lib/features/trip/screens/trip_map_screen.dart').readAsStringSync().replaceAll('\r\n', '\n');
    expect(src.contains('DS.s(22.5)'), isFalse);
    expect(src.contains('DS.f(21)'), isFalse);
    expect(src.contains('_stops.draw(map, stops,'), isTrue);
    expect(src.contains('below: map.circleManager?.layerIds.first'), isTrue, reason: 'stops sit above the routes and the selection');
    final redraw = RegExp(r'Future<void> _redraw\([\s\S]*?\n  \}').firstMatch(src)!.group(0)!;
    expect(redraw.indexOf('_addLine(map'), lessThan(redraw.indexOf('_stops.draw(')), reason: 'route line stays under the stops');
    expect(src.contains('ctrl.onFeatureTapped.add(_onFeatureTapped)'), isTrue);
    expect(src.contains('_map?.onFeatureTapped.remove(_onFeatureTapped)'), isTrue);
    expect(src.contains('_stops.setOpacity(map, _stopOpacity())'), isTrue);
  });
}
