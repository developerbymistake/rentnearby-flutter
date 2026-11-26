import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:bakhli/features/trip/map/map_marker_sizes.dart';
import 'package:bakhli/features/trip/map/trip_marker_images.dart';
import 'package:bakhli/features/trip/map/trip_route_stops.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _ring = Color(0xFFFF8A3D);
const _cases = [(3, 12), (6, 8)];
const _textureBudgetBytes = 32 * 1024 * 1024;

List<RouteStop> _stops(int days, int perDay) => [
      for (var d = 1; d <= days; d++)
        for (var i = 0; i < perDay; i++)
          RouteStop(
            day: d,
            index: i,
            number: i + 1,
            spot: DiscoverySpot(id: 'd${d}s$i', lat: 30, lon: 78, category: 'temple', rank: 0, name: 'd${d}s$i'),
            ring: _ring,
          ),
    ];

Future<ui.Image> _decode(Uint8List png) async => (await (await ui.instantiateImageCodec(png)).getNextFrame()).image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(DS.applyApproved);
  tearDown(DS.debugReset);

  testWidgets('measured stop image size at 1x: the zoom-17 canvas is the marker plus ring and shadow', (tester) async {
    await tester.runAsync(() async {
      final t = DiscTuning.tripStops;
      final img = await _decode(await const CanvasMarkerPainter().stop(category: 'temple', ring: _ring, number: 1, t: t));
      expect(img.width, img.height);
      expect(img.width, t.px(CanvasMarkerPainter.stopCanvasDp(t)));
      expect(img.width / t.pxPerDp, greaterThanOrEqualTo(MapMarkerSizes.dp(MapMarkerSizes.photoFull)));
      final z14 = img.width * (MapMarkerSizes.photoMid / MapMarkerSizes.photoFull);
      final z10 = img.width * (MapMarkerSizes.photoMin / MapMarkerSizes.photoFull);
      expect(z10, lessThan(z14));
      expect(z14, lessThan(img.width));
    });
  });

  for (final c in _cases) {
    testWidgets('${c.$1} days x ${c.$2} spots: every stop is cached once, fits the cache and the texture budget', (tester) async {
      await tester.runAsync(() async {
        final stops = _stops(c.$1, c.$2);
        final t = DiscTuning.tripStops;
        final routeStops = TripRouteStops();
        expect(stops.length, lessThanOrEqualTo(TripRouteStops.cacheMax));
        expect({for (final s in stops) routeStops.plainKey(s)}.length, stops.length, reason: 'one cache key per stop, none shared across days');
        final side = t.px(CanvasMarkerPainter.stopCanvasDp(t));
        expect(side * side * 4 * stops.length, lessThan(_textureBudgetBytes));

        final sw = Stopwatch()..start();
        var total = 0;
        for (final s in stops) {
          final png = await const CanvasMarkerPainter().stop(category: s.spot.category, ring: s.ring, number: s.number, t: t);
          total += png.length;
        }
        sw.stop();
        expect(total, greaterThan(0));
        expect(sw.elapsedMilliseconds, lessThan(60000), reason: 'one-time render of all stops, not per frame');
      });
    });
  }
}
