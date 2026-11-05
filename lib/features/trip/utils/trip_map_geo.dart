import 'dart:math';

import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../utils/geo_distance.dart';

class TripMapGeo {
  TripMapGeo._();

  static const double spotMaxKmFromCity = 200;
  static const double _metersPerPixelZ0 = 78271.51696;

  static double haversineKm(LatLng a, LatLng b) => GeoDistance.km(a.latitude, a.longitude, b.latitude, b.longitude);

  static LatLng? midpointByLength(List<LatLng> line) {
    if (line.isEmpty) return null;
    if (line.length == 1) return line.first;
    final seg = List<double>.filled(line.length - 1, 0);
    var total = 0.0;
    for (var i = 0; i < seg.length; i++) {
      seg[i] = haversineKm(line[i], line[i + 1]);
      total += seg[i];
    }
    if (total <= 0) return line.first;
    final half = total / 2;
    var walked = 0.0;
    for (var i = 0; i < seg.length; i++) {
      if (seg[i] > 0 && walked + seg[i] >= half) {
        final t = (half - walked) / seg[i];
        final a = line[i], b = line[i + 1];
        return LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);
      }
      walked += seg[i];
    }
    return line.last;
  }

  static Iterable<LatLng> geometryPoints(Map<String, dynamic>? geometry) sync* {
    if (geometry == null) return;
    final coords = geometry['coordinates'];
    if (coords is! List) return;
    final lines = geometry['type'] == 'MultiLineString' ? coords : [coords];
    for (final line in lines) {
      if (line is! List) continue;
      for (final c in line) {
        if (c is List && c.length >= 2 && c[0] is num && c[1] is num) {
          final lon = (c[0] as num).toDouble(), lat = (c[1] as num).toDouble();
          if (lat.isFinite && lon.isFinite) yield LatLng(lat, lon);
        }
      }
    }
  }

  static LatLngBounds? bounds(Iterable<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in points) {
      if (!p.latitude.isFinite || !p.longitude.isFinite) continue;
      minLat = minLat == null ? p.latitude : min(minLat, p.latitude);
      maxLat = maxLat == null ? p.latitude : max(maxLat, p.latitude);
      minLng = minLng == null ? p.longitude : min(minLng, p.longitude);
      maxLng = maxLng == null ? p.longitude : max(maxLng, p.longitude);
    }
    if (minLat == null) return null;
    return LatLngBounds(southwest: LatLng(minLat, minLng!), northeast: LatLng(maxLat!, maxLng!));
  }

  // Zoom at which spanKm fills viewportPx logical pixels at this latitude (512 px tiles).
  static double zoomToFit(double spanKm, double latitude, double viewportPx) {
    if (spanKm <= 0 || viewportPx <= 0) return 22;
    final c = cos(latitude.clamp(-85.0, 85.0) * pi / 180);
    return log(_metersPerPixelZ0 * c * viewportPx / (spanKm * 1000)) / ln2;
  }

  static double oneCityMinZoom(double latitude, double viewportPx, {double floor = 4, double ceiling = 8}) {
    final z = zoomToFit(2 * spotMaxKmFromCity, latitude, viewportPx).floorToDouble();
    return z.clamp(floor, ceiling).toDouble();
  }
}
