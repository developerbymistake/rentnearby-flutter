import 'dart:ui' show Color;

import 'package:bakhli/design/design.dart';
import 'package:bakhli/features/buddy/viewer/widgets/viewer_map_scene.dart';
import 'package:bakhli/features/trip/map/discovery_api.dart';
import 'package:bakhli/features/trip/map/map_marker_sizes.dart';
import 'package:bakhli/features/trip/map/trip_marker_images.dart';
import 'package:bakhli/features/trip/map/trip_route_stops.dart';
import 'package:flutter_test/flutter_test.dart';

RouteStop _stop(String id, int n) => RouteStop(
      day: 1,
      index: n - 1,
      number: n,
      spot: DiscoverySpot(id: id, lat: 30, lon: 78, category: 'temple', rank: 0, name: id, thumbUrl: 'https://a/$id.jpg'),
      ring: const Color(0xFFFF8A3D),
    );

void main() {
  setUp(DS.applyApproved);
  tearDown(DS.debugReset);

  test('one growth constant: 3x times 1.15', () {
    expect(MapMarkerSizes.growth, 1.15);
    expect(MapMarkerSizes.scale, closeTo(3.45, 1e-9));
    expect(DiscTuning.markerScale, MapMarkerSizes.scale);
  });

  test('trip, stay and stops read the one size source', () {
    for (final t in [DiscTuning.trip, DiscTuning.stay, DiscTuning.tripStops]) {
      expect(t.photoDp, MapMarkerSizes.dp(MapMarkerSizes.photoFull));
      expect(t.photoMidDp, MapMarkerSizes.dp(MapMarkerSizes.photoMid));
      expect(t.photoMinDp, MapMarkerSizes.dp(MapMarkerSizes.photoMin));
      expect(t.badgeDp, MapMarkerSizes.dp(MapMarkerSizes.badgeFull));
      expect(t.dotDp, MapMarkerSizes.dp(MapMarkerSizes.dotFull));
      expect(t.selDotDp, MapMarkerSizes.dp(MapMarkerSizes.selDotFull));
      expect(t.haloPhotoDp, MapMarkerSizes.dp(MapMarkerSizes.haloPhoto));
      expect(t.haloDotDp, MapMarkerSizes.dp(MapMarkerSizes.haloDot));
      expect(t.stopBadgeDp, MapMarkerSizes.dp(MapMarkerSizes.stopBadge));
      expect(t.thumbPx, MapMarkerSizes.thumbPx);
      expect(t.sizeScale, MapMarkerSizes.scale);
    }
  });

  test('itinerary stops are exactly as big as other spots, at every zoom', () {
    final spots = DiscTuning.trip, stops = DiscTuning.tripStops;
    expect(stops.photoIconSize, spots.photoIconSize);
    expect(stops.photoDp, spots.photoDp);
    expect(TripRouteStops().iconSize, spots.photoIconSize);
    expect(stops.haloRadiusAt('planned', DiscTuning.zoomIn, dotKind: 'dot', plannedKind: 'planned', photoScale: 1),
        closeTo(spots.haloPhotoDp / 2, 1e-9));
  });

  test('other spots are 15 percent bigger than the previous 3x size', () {
    expect(DiscTuning.trip.photoDp, closeTo(DS.s(90 * 3) * 1.15, 1e-9));
    expect(DiscTuning.trip.badgeDp, closeTo(DS.s(60 * 3) * 1.15, 1e-9));
  });

  test('the viewer map reads the same source (flat at the zoom-14 size)', () {
    final v = ViewerMapScene.tuning;
    expect(v.photoDp, DiscTuning.tripStops.photoMidDp);
    expect(v.sizeScale, MapMarkerSizes.scale);
    expect(v.stopBadgeDp, closeTo(DiscTuning.tripStops.stopBadgeDp! * 75 / 90, 1e-9));
    final e = TripRouteStops(tuning: v).iconSize as List;
    expect(e.length, 7);
    expect([e[3], e[5]], [DiscTuning.zoomOut, DiscTuning.zoomMid]);
    expect([e[4], e[6]], [1.0, 1.0], reason: 'the stop under the fixed halo keeps one size at every zoom');
  });

  test('viewer day ring, outline and number match the trip stop at zoom 14', () {
    final v = ViewerMapScene.tuning, t = DiscTuning.tripStops;
    final z14 = t.photoMidDp! / t.photoDp;
    expect(CanvasMarkerPainter.stopRingDp(v), closeTo(CanvasMarkerPainter.stopRingDp(t) * z14, 1e-9));
    expect(CanvasMarkerPainter.stopBadgeRingDp(v), closeTo(CanvasMarkerPainter.stopBadgeRingDp(t) * z14, 1e-9));
    expect(CanvasMarkerPainter.stopPhotoRingDp(v), closeTo(CanvasMarkerPainter.stopPhotoRingDp(t) * z14, 1e-9));
    expect(CanvasMarkerPainter.stopNumberStyle(v).fontSize!, closeTo(CanvasMarkerPainter.stopNumberStyle(t).fontSize! * z14, 1e-9));
    expect(ViewerMapScene.haloStroke, closeTo(DS.s(MapMarkerSizes.stopRing) * MapMarkerSizes.scale, 1e-9));
    expect(ViewerMapScene.haloRadius, greaterThan(TripRouteStops(tuning: v).reachDp));
  });

  test('camera fit room is the day ring outer radius at zoom 14', () {
    final t = DiscTuning.tripStops;
    final want = (t.photoDp / 2 + CanvasMarkerPainter.stopRingDp(t)) * t.photoMidDp! / t.photoDp;
    expect(TripRouteStops().reachDp, closeTo(want, 1e-9));
    expect(TripRouteStops(tuning: ViewerMapScene.tuning).reachDp,
        closeTo(ViewerMapScene.tuning.photoDp / 2 + CanvasMarkerPainter.stopRingDp(ViewerMapScene.tuning), 1e-9));
  });

  test('number badge, number text and day ring scale with the marker size, caption style kept', () {
    final t = DiscTuning.tripStops;
    final style = CanvasMarkerPainter.stopNumberStyle(t);
    final caption = TypeTokens.caption;
    expect(style.fontFamily, caption.fontFamily);
    expect(style.fontWeight, caption.fontWeight);
    final flat = DiscTuning(photoMax: 40, photoDp: 100);
    expect(style.fontSize! / CanvasMarkerPainter.stopNumberStyle(flat).fontSize!, closeTo(MapMarkerSizes.scale * 1.2, 1e-9));
    expect(CanvasMarkerPainter.stopRingDp(t), closeTo(DS.s(3) * MapMarkerSizes.scale, 1e-9));
    expect(CanvasMarkerPainter.stopBadgeRingDp(t), closeTo(1.5 * MapMarkerSizes.scale, 1e-9));
    expect(CanvasMarkerPainter.stopPhotoRingDp(t), closeTo(2 * MapMarkerSizes.scale, 1e-9));
    expect(CanvasMarkerPainter.stopBadgeRingDp(flat), 1.5, reason: 'a flat 1x tuning keeps the old outline');
  });

  test('stop cache key carries the size, the photo, the colour and the number', () {
    final s = _stop('a', 1);
    final stops = TripRouteStops(tuning: DiscTuning.tripStops);
    final other = TripRouteStops(tuning: DiscTuning(photoMax: 40, photoDp: 54));
    expect(stops.keyOf(s), stops.keyOf(s));
    expect(stops.keyOf(s), isNot(other.keyOf(s)));
    expect(stops.keyOf(s), isNot(stops.plainKey(s)));
    expect(stops.keyOf(_stop('a', 2)), isNot(stops.keyOf(s)));
  });
}
