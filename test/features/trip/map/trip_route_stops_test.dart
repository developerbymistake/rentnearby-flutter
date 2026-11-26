import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:bakhli/features/trip/map/map_marker_sizes.dart';
import 'package:bakhli/features/trip/map/trip_marker_images.dart';
import 'package:bakhli/features/trip/map/trip_route_stops.dart';
import 'package:bakhli/features/trip/models/trip_spot_category.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'route_stops_fake_map.dart';

const _ring = Color(0xFFFF8A3D);

DiscoverySpot _spot(String id, {String? thumb}) =>
    DiscoverySpot(id: id, lat: 30, lon: 78, category: 'temple', rank: 0, name: id, thumbUrl: thumb);

RouteStop _stop(int day, int index, int number) =>
    RouteStop(day: day, index: index, number: number, spot: _spot('s$number'), ring: _ring);

const _dayColors = [Color(0xFFFF8A3D), Color(0xFF3D8AFF), Color(0xFF2BB673)];
const _fourMb = 4 * 1024 * 1024;

List<RouteStop> _trip(int days, int perDay, {String? thumb}) {
  final out = <RouteStop>[];
  for (var d = 1; d <= days; d++) {
    for (var i = 0; i < perDay; i++) {
      out.add(RouteStop(day: d, index: i, number: out.length + 1, spot: _spot('d${d}s$i', thumb: thumb), ring: _dayColors[(d - 1) % _dayColors.length]));
    }
  }
  return out;
}

const _thumbUrl = 'https://img.example.com/spot.jpg';

int _sentTo(List<String> images, Set<String> slots) => images.where(slots.contains).length;

Future<void> _until(bool Function() done) async {
  for (var k = 0; k < 400 && !done(); k++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

List<double> _ops(List<RouteStop> stops, int? day) => [for (final s in stops) day == null || s.day == day ? 1.0 : 0.35];

Set<String> _slotsOf(List<RouteStop> stops, int day) => {
      for (var i = 0; i < stops.length; i++)
        if (stops[i].day == day) TripRouteStops.imageOf(i),
    };

class _CountingPainter extends CanvasMarkerPainter {
  int stops = 0;

  @override
  Future<Uint8List> stop({Uint8List? thumb, required String category, required Color ring, required int number, required DiscTuning t}) {
    stops++;
    return super.stop(thumb: thumb, category: category, ring: ring, number: number, t: t);
  }
}

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

  test('stops are one GeoJSON point per stop: the full day takes its photo slot, other days the shared day-colour dot', () {
    final stops = [_stop(1, 0, 1), _stop(1, 1, 2), _stop(2, 0, 3)];
    final g = TripRouteStops.geoJson(stops, [1, 1, 0.35], fullDay: 1);
    final f = g['features'] as List;
    expect(f.length, 3);
    final last = f.last as Map;
    expect(last['id'], 2);
    expect((last['geometry'] as Map)['coordinates'], [78, 30]);
    expect(last['properties'], {'img': TripRouteStops.dotImageOf(_ring), 'k': TripRouteStops.kindDot, 'op': 0.35, 'n': 3});
    expect((f.first as Map)['properties'], {'img': TripRouteStops.imageOf(0), 'k': TripRouteStops.kindFull, 'op': 1, 'n': 1 + TripRouteStops.fullLift});
    final all = TripRouteStops.geoJson(stops, [1, 1, 1], fullDay: null)['features'] as List;
    expect(all.map((e) => ((e as Map)['properties'] as Map)['k']).toSet(), {TripRouteStops.kindDot}, reason: 'All view: dots only');
  });

  test('route stops are as big as other spots: 151.8 / 207 / 248.4 dp at zoom 10 / 14 / 17', () {
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
    expect((e[4] as double) * t.photoDp, closeTo(44 * MapMarkerSizes.scale, 1e-9));
    expect(e[5], DiscTuning.zoomMid);
    expect((e[6] as double) * t.photoDp, closeTo(60 * MapMarkerSizes.scale, 1e-9));
    expect(e[7], DiscTuning.zoomIn);
    expect(e[8], 1.0);
    expect(CanvasMarkerPainter.stopBadgeDp(t) * (e[6] as double), closeTo(36 * MapMarkerSizes.scale, 1e-9), reason: 'order badge scales with the marker size');
    final number = CanvasMarkerPainter.stopNumberStyle(t);
    final caption = TypeTokens.caption;
    expect(number.fontSize! * (e[6] as double), closeTo(caption.fontSize! * MapMarkerSizes.scale, 1e-9), reason: 'order number is the caption style scaled with the badge');
    expect(number.fontFamily, caption.fontFamily);
    expect(number.fontWeight, caption.fontWeight);
    expect(number.height, 1);
    final p = stops.layerProps.toJson();
    final layer = p['icon-size'] as List;
    expect(layer, stops.layerIconSize);
    expect(layer.take(3).toList(), e.take(3).toList());
    expect([layer[3], layer[5], layer[7]], [e[3], e[5], e[7]], reason: 'same zoom stops as before');
    for (var k = 0; k < 3; k++) {
      final m = layer[4 + 2 * k] as List;
      expect(m.take(3).toList(), ['match', ['get', TripRouteStops.kindKey], TripRouteStops.kindDot]);
      expect(m[4], e[4 + 2 * k], reason: 'a full stop keeps the photo stop zoom ramp');
      expect(m[3], (t.dotIconSize as List)[4 + 2 * k], reason: 'a dot follows the spot dot ramp');
    }
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
      final white = _rgb(r, c - rad + CanvasMarkerPainter.stopPhotoRingDp(t) / 2, c);
      expect(white[0], greaterThan(200));
      expect(white[2], greaterThan(200));
      expect(_rgb(r, c - rad + CanvasMarkerPainter.stopPhotoRingDp(t) + 2, c)[2], greaterThan(150), reason: 'photo starts inside the scaled white ring');
      final ring = _rgb(r, c - rad - CanvasMarkerPainter.stopRingDp(t) / 2, c);
      expect(ring[0], greaterThan(200), reason: 'route ring outside the white ring');
      expect(ring[2], lessThan(120));
      final outer = rad + CanvasMarkerPainter.stopRingDp(t);
      final badge = Offset(c + outer * 0.7071, c - outer * 0.7071);
      final b = CanvasMarkerPainter.stopBadgeDp(t) / 2;
      final column = [for (var dy = -b; dy <= -1; dy++) _rgb(r, badge.dx, badge.dy + dy)];
      expect(column.any((p) => p[0] > 200 && p[2] < 120), isTrue, reason: 'badge filled with the route colour');
      final outline = _rgb(r, badge.dx, badge.dy - b + CanvasMarkerPainter.stopBadgeRingDp(t) / 2);
      expect(outline.take(3).every((v) => v > 200), isTrue, reason: 'white badge outline scales with the marker');
      expect(_rgb(r, 0, side - 1.0)[3], 0, reason: 'transparent corner');
    });
  });

  testWidgets('stop marker without a photo shows the category colour', (tester) async {
    await tester.runAsync(() async {
      const painter = CanvasMarkerPainter();
      final t = DiscTuning.tripStops;
      final r = await _raw(await painter.stop(category: 'temple', ring: _ring, number: 1, t: t));
      final c = t.px(CanvasMarkerPainter.stopCanvasDp(t)) / 2;
      final inner = t.photoDp / 2 - CanvasMarkerPainter.stopPhotoRingDp(t);
      final px = _rgb(r, c, c + inner * 0.85);
      final want = TripSpotCategory.colorOf('temple');
      expect((px[0] - (want.r * 255).round()).abs(), lessThan(12));
      expect((px[2] - (want.b * 255).round()).abs(), lessThan(12));
      final bad = await painter.stop(thumb: Uint8List.fromList([1, 2, 3]), category: 'temple', ring: _ring, number: 1, t: t);
      expect(await painter.valid(bad), isTrue, reason: 'a broken photo falls back to the icon');
    });
  });

  testWidgets('a redraw sends only the stop images that changed; a new style sends them all again', (tester) async {
    await tester.runAsync(() async {
      final map = RouteStopsFakeMap();
      final stops = TripRouteStops();
      final three = [_stop(1, 0, 1), _stop(1, 1, 2), _stop(1, 2, 3)];
      await stops.draw(map, three, [1, 1, 1], fullDay: 1);
      expect(map.images, [TripRouteStops.imageOf(0), TripRouteStops.imageOf(1), TripRouteStops.imageOf(2)]);
      map.images.clear();
      await stops.draw(map, three, [1, 1, 0.35], fullDay: 1);
      expect(map.images, isEmpty, reason: 'same stops, same images: nothing crosses the channel');
      await stops.draw(map, [three[0], three[1], _stop(1, 2, 4)], [1, 1, 1], fullDay: 1);
      expect(map.images, [TripRouteStops.imageOf(2)], reason: 'only the slot whose number changed');
      map.images.clear();
      stops.resetImages();
      await stops.draw(map, three, [1, 1, 1], fullDay: 1);
      expect(map.images, [TripRouteStops.imageOf(0), TripRouteStops.imageOf(1), TripRouteStops.imageOf(2)]);
      stops.dispose();
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
    expect(src.contains('_stops.setOpacity(map, _stopOpacity(), fullDay: _stopFullDay)'), isTrue);
    expect(src.contains('fullDay: _stopFullDay);'), isTrue);
    expect(src.contains('int? get _stopFullDay => _plan.mapFocus == TripMapFocus.day ? _selected : null;'), isTrue,
        reason: 'full photo stops only in the day view, for the selected day');
    final style = RegExp(r'Future<void> _onStyleLoaded\(\)[\s\S]*?\n  \}').firstMatch(src)!.group(0)!;
    expect(style.contains('_stops.resetImages();'), isTrue, reason: 'a new style drops the stop images');
    final viewer = File('lib/features/buddy/viewer/widgets/viewer_route_map.dart').readAsStringSync().replaceAll('\r\n', '\n');
    final viewerStyle = RegExp(r'void _onStyleLoaded\(\) \{[\s\S]*?\n  \}').firstMatch(viewer)!.group(0)!;
    expect(viewerStyle.contains('_stops.resetImages();'), isTrue);
    expect(viewer.contains('fullDay: scene.fullDay(_v.selected)'), isTrue);
  });

  test('camera fits leave the stop marker room on every side', () {
    final trip = File('lib/features/trip/screens/trip_map_screen.dart').readAsStringSync().replaceAll('\r\n', '\n');
    final fit = RegExp(r'Future<void> _fitCamera\(\)[\s\S]*?\n  \}').firstMatch(trip)!.group(0)!;
    expect(fit.contains('final reach = _stops.reachFor(_stopFullDay);'), isTrue);
    expect(fit.contains('DS.s(24) + reach'), isTrue);
    expect(fit.contains('size.width * 0.12) + reach, size.width / 4)'), isTrue);
    final viewer = File('lib/features/buddy/viewer/widgets/viewer_route_map.dart').readAsStringSync();
    expect(viewer.contains('widget.padding() + EdgeInsets.all(ViewerMapScene.haloRadiusOf(full: _v.scene.fullDay(_v.selected) != null))'), isTrue);
  });

  test('camera room follows the view: the photo stop ring in the day view, only the dot radius when every stop is a dot', () {
    DS.applyApproved();
    addTearDown(DS.debugReset);
    final stops = TripRouteStops();
    final t = DiscTuning.tripStops;
    expect(stops.reachFor(2), stops.reachDp);
    expect(stops.reachFor(null), closeTo(t.dotMidDp! / 2, 1e-9));
    expect(stops.reachFor(null), closeTo(MapMarkerSizes.dp(MapMarkerSizes.dotMid) / 2, 1e-9));
    expect(stops.reachFor(null), lessThan(stops.reachDp));
  });

  group('stop markers by view (10 days x 6 places)', () {
    setUp(DS.applyApproved);
    tearDown(DS.debugReset);

    testWidgets('day view: full photo stops only for the selected day (6), shared day-colour dots for the others', (tester) async {
      await tester.runAsync(() async {
        final map = RouteStopsFakeMap();
        final stops = TripRouteStops();
        final trip = _trip(10, 6);
        await stops.draw(map, trip, _ops(trip, 2), fullDay: 2);
        final full = await map.fullTextures();
        expect(full.keys.toSet(), _slotsOf(trip, 2));
        expect(full.length, 6);
        expect(stops.fullSlots, {for (var i = 6; i < 12; i++) i});
        expect(map.dotImages, {for (final s in trip) if (s.day != 2) TripRouteStops.dotImageOf(s.ring)});
        expect(map.dotImages.length, _dayColors.length, reason: 'one dot image per day colour, shared by every dot of that colour');
        final props = map.featureProps;
        expect(props.length, trip.length);
        for (var i = 0; i < trip.length; i++) {
          final isDay = trip[i].day == 2;
          expect(props[i]['k'], isDay ? TripRouteStops.kindFull : TripRouteStops.kindDot);
          expect(props[i]['img'], isDay ? TripRouteStops.imageOf(i) : TripRouteStops.dotImageOf(trip[i].ring));
          expect(props[i]['op'], isDay ? 1.0 : 0.35, reason: 'other days dim as before');
        }
        expect(stops.at(0)?.day, 1, reason: 'a dot is still a tappable stop');
        stops.dispose();
      });
    });

    testWidgets('switching days swaps the full images in one source update; the old day is cleared; back again uses the PNG cache', (tester) async {
      await tester.runAsync(() async {
        final map = RouteStopsFakeMap();
        final painter = _CountingPainter();
        final stops = TripRouteStops(painter: painter);
        final trip = _trip(10, 6);
        await stops.draw(map, trip, _ops(trip, 2), fullDay: 2);
        expect(painter.stops, 6);
        map.images.clear();
        final sets = map.sourceSets;
        await stops.setOpacity(map, _ops(trip, 3), fullDay: 3);
        expect((await map.fullTextures()).keys.toSet(), _slotsOf(trip, 3));
        expect(map.sourceSets, sets + 1, reason: 'one source update per day pick, no redraw');
        expect(map.images.toSet(), {..._slotsOf(trip, 3), ..._slotsOf(trip, 2)}, reason: 'day 3 sent, day 2 cleared');
        expect(map.images.length, 12);
        expect(painter.stops, 12);
        map.images.clear();
        await stops.setOpacity(map, _ops(trip, 2), fullDay: 2);
        expect((await map.fullTextures()).keys.toSet(), _slotsOf(trip, 2));
        expect(painter.stops, 12, reason: 'day 2 comes back from the PNG cache, nothing is painted again');
        map.images.clear();
        await stops.setOpacity(map, _ops(trip, 2), fullDay: 2);
        expect(map.images, isEmpty);
        expect(map.sourceSets, sets + 2, reason: 'same view: nothing sent');
        stops.dispose();
      });
    });

    testWidgets('All view: every stop is a dot, no photo stop is held', (tester) async {
      await tester.runAsync(() async {
        final trip = _trip(10, 6);
        final fresh = RouteStopsFakeMap();
        final a = TripRouteStops();
        await a.draw(fresh, trip, _ops(trip, null), fullDay: null);
        expect(fresh.images.every((n) => n.startsWith(TripRouteStops.dotPrefix)), isTrue);
        expect(fresh.images.length, _dayColors.length);
        expect(fresh.featureProps.map((p) => p['k']).toSet(), {TripRouteStops.kindDot});
        a.dispose();

        final map = RouteStopsFakeMap();
        final b = TripRouteStops();
        await b.draw(map, trip, _ops(trip, 4), fullDay: 4);
        await b.setOpacity(map, _ops(trip, null), fullDay: null);
        expect(await map.fullTextures(), isEmpty, reason: 'the day images are cleared when All is picked');
        expect(b.fullSlots, isEmpty);
        expect(map.featureProps.map((p) => p['k']).toSet(), {TripRouteStops.kindDot});
        b.dispose();
      });
    });

    testWidgets('photo stop textures stay under 4 MB on every day of a 10-day 60-stop trip', (tester) async {
      await tester.runAsync(() async {
        final map = RouteStopsFakeMap();
        final stops = TripRouteStops();
        final trip = _trip(10, 6);
        final t = DiscTuning.tripStops;
        final side = t.px(CanvasMarkerPainter.stopCanvasDp(t));
        expect(side * side * 4 * trip.length, greaterThan(_fourMb), reason: 'one image per stop, as before, would not fit');
        await stops.draw(map, trip, _ops(trip, 1), fullDay: 1);
        for (var d = 1; d <= 10; d++) {
          if (d > 1) await stops.setOpacity(map, _ops(trip, d), fullDay: d);
          final full = await map.fullTextures();
          expect(full.length, 6);
          expect(full.values.fold<int>(0, (a, b) => a + b), lessThan(_fourMb));
        }
        stops.dispose();
      });
    });

    testWidgets('photo stops: the shown day gets the plain icon first, then its photo, one painter call each', (tester) async {
      await tester.runAsync(() async {
        final png = await _pngOf(96, 96, const Color(0xFF3366CC));
        final map = RouteStopsFakeMap();
        final painter = _CountingPainter();
        final stops = TripRouteStops(images: TripMarkerImages(fetch: (_) async => png), painter: painter);
        final trip = _trip(10, 6, thumb: _thumbUrl);
        final day2 = _slotsOf(trip, 2);
        await stops.draw(map, trip, _ops(trip, 2), fullDay: 2);
        expect(_sentTo(map.images, day2), 6, reason: 'plain icons before any photo arrives');
        await _until(() => _sentTo(map.images, day2) >= 12);
        expect(_sentTo(map.images, day2), 12, reason: '6 plain + 6 photo sends');
        expect(painter.stops, 12);
        expect(stops.fullSlots, {for (var i = 6; i < 12; i++) i});
        expect((await map.fullTextures()).keys.toSet(), day2);
        stops.dispose();
      });
    });

    testWidgets('photo stops: back to a day sends each slot once from the PNG cache, with no plain pass', (tester) async {
      await tester.runAsync(() async {
        final png = await _pngOf(96, 96, const Color(0xFF3366CC));
        final map = RouteStopsFakeMap();
        final painter = _CountingPainter();
        final stops = TripRouteStops(images: TripMarkerImages(fetch: (_) async => png), painter: painter);
        final trip = _trip(10, 6, thumb: _thumbUrl);
        final day2 = _slotsOf(trip, 2), day3 = _slotsOf(trip, 3);
        await stops.draw(map, trip, _ops(trip, 2), fullDay: 2);
        await _until(() => _sentTo(map.images, day2) >= 12);
        map.images.clear();
        await stops.setOpacity(map, _ops(trip, 3), fullDay: 3);
        await _until(() => _sentTo(map.images, day3) >= 12);
        expect(painter.stops, 24);
        map.images.clear();
        await stops.setOpacity(map, _ops(trip, 2), fullDay: 2);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(_sentTo(map.images, day2), 6, reason: 'one send per slot, straight from the cache');
        expect({for (final n in map.images) if (day2.contains(n)) n}, day2);
        expect(painter.stops, 24, reason: 'nothing painted again');
        expect(stops.fullSlots, {for (var i = 6; i < 12; i++) i});
        expect((await map.fullTextures()).keys.toSet(), day2);
        stops.dispose();
      });
    });

    testWidgets('photo stops: a photo that arrives after the day changed never lands in the old day slot', (tester) async {
      await tester.runAsync(() async {
        final png = await _pngOf(96, 96, const Color(0xFF3366CC));
        final gate = Completer<Uint8List?>();
        final map = RouteStopsFakeMap();
        final stops = TripRouteStops(images: TripMarkerImages(fetch: (_) => gate.future));
        final trip = _trip(10, 6, thumb: _thumbUrl);
        final day2 = _slotsOf(trip, 2), day3 = _slotsOf(trip, 3);
        await stops.draw(map, trip, _ops(trip, 2), fullDay: 2);
        await stops.setOpacity(map, _ops(trip, 3), fullDay: 3);
        expect(_sentTo(map.images, day2), 12, reason: 'day 2 plain icons, then the clear');
        map.images.clear();
        gate.complete(png);
        await _until(() => _sentTo(map.images, day3) >= 6);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(_sentTo(map.images, day2), 0, reason: 'no addImage for an old day slot after its blank');
        expect(_sentTo(map.images, day3), 6, reason: 'the new day gets its photos');
        expect(stops.fullSlots, {for (var i = 12; i < 18; i++) i});
        expect((await map.fullTextures()).keys.toSet(), day3);
        stops.dispose();
      });
    });
  });

  test('a stop photo is decoded no larger than the circle it fills at zoom 17, never upscaled', () {
    DS.applyApproved();
    addTearDown(DS.debugReset);
    final t = DiscTuning.tripStops;
    expect(CanvasMarkerPainter.stopPhotoPx(t), t.px(t.photoDp - 2 * CanvasMarkerPainter.stopPhotoRingDp(t)));
    expect(CanvasMarkerPainter.coverSize(1000, 800, 200), (width: 250, height: 200));
    expect(CanvasMarkerPainter.coverSize(600, 900, 200), (width: 200, height: 300));
    expect(CanvasMarkerPainter.coverSize(96, 120, 235), (width: 96, height: 120), reason: 'a small thumb keeps its own size');
  });

  testWidgets('a big photo still paints the same zoom-17 stop canvas', (tester) async {
    await tester.runAsync(() async {
      final t = DiscTuning.tripStops;
      final png = await const CanvasMarkerPainter().stop(thumb: await _pngOf(1200, 800, const Color(0xFF3366CC)), category: 'temple', ring: _ring, number: 1, t: t);
      final r = await _raw(png);
      expect(r.w, t.px(CanvasMarkerPainter.stopCanvasDp(t)));
      final c = r.w / 2;
      expect(_rgb(r, c, c)[2], greaterThan(150), reason: 'photo inside');
    });
  });
}
