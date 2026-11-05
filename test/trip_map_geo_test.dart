import 'package:bakhli/features/trip/utils/trip_map_geo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

void main() {
  test('badge sits at the middle by length, not the middle vertex', () {
    final line = [
      const LatLng(0, 0),
      const LatLng(0, 1),
      const LatLng(0, 1.01),
      const LatLng(0, 1.02),
      const LatLng(0, 1.03),
    ];
    final m = TripMapGeo.midpointByLength(line)!;
    expect(m.latitude, closeTo(0, 1e-9));
    expect(m.longitude, closeTo(0.515, 1e-6));
  });

  test('midpoint edge cases', () {
    expect(TripMapGeo.midpointByLength(const []), isNull);
    expect(TripMapGeo.midpointByLength(const [LatLng(29, 79)]), const LatLng(29, 79));
    expect(TripMapGeo.midpointByLength(const [LatLng(29, 79), LatLng(29, 79)]), const LatLng(29, 79));
    final two = TripMapGeo.midpointByLength(const [LatLng(29, 79), LatLng(30, 79)])!;
    expect(two.latitude, closeTo(29.5, 1e-9));
  });

  test('fit bounds include the road, not only the spots', () {
    final route = {
      'type': 'LineString',
      'coordinates': [
        [79.454, 29.392],
        [79.519, 29.383],
        [79.516, 29.425],
      ],
    };
    final b = TripMapGeo.bounds([
      const LatLng(29.392, 79.454),
      const LatLng(29.425, 79.516),
      ...TripMapGeo.geometryPoints(route),
    ])!;
    expect(b.southwest.latitude, 29.383);
    expect(b.northeast.longitude, 79.519);
    expect(TripMapGeo.bounds(const []), isNull);
    expect(TripMapGeo.geometryPoints(null), isEmpty);
  });

  test('one-city zoom floor allows the 200 km spot rule', () {
    expect(TripMapGeo.zoomToFit(400, 29, 304), closeTo(5.70, 0.01));
    expect(TripMapGeo.oneCityMinZoom(29, 304), 5);
    expect(TripMapGeo.oneCityMinZoom(29, 2000), 8);
    expect(TripMapGeo.oneCityMinZoom(29, 10), 4);
  });
}
