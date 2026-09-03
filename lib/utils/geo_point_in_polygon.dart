/// Standard even-odd ray-casting point-in-polygon, applied over a GeoJSON
/// `FeatureCollection` of `Polygon`/`MultiPolygon` geometries. Toggling
/// `inside` once per ring (rather than testing the outer ring then
/// subtracting holes) is the well-known way to get holes for free: a point
/// inside an interior (hole) ring flips back to "outside" automatically.
bool isPointInGeoJsonFeatureCollection(double lat, double lng, Map<String, dynamic> featureCollection) {
  final features = featureCollection['features'];
  if (features is! List) return false;
  for (final feature in features) {
    if (feature is! Map<String, dynamic>) continue;
    final geometry = feature['geometry'];
    if (geometry is! Map<String, dynamic>) continue;
    if (_isPointInGeometry(lat, lng, geometry)) return true;
  }
  return false;
}

bool _isPointInGeometry(double lat, double lng, Map<String, dynamic> geometry) {
  final type = geometry['type'];
  final coordinates = geometry['coordinates'];
  if (coordinates is! List) return false;
  if (type == 'Polygon') {
    return _isPointInPolygonRings(lat, lng, coordinates);
  }
  if (type == 'MultiPolygon') {
    for (final polygon in coordinates) {
      if (polygon is List && _isPointInPolygonRings(lat, lng, polygon)) return true;
    }
  }
  return false;
}

// [rings]: first entry is the outer boundary, any further entries are holes.
bool _isPointInPolygonRings(double lat, double lng, List rings) {
  var inside = false;
  for (final ring in rings) {
    if (ring is List && _isPointInRing(lat, lng, ring)) inside = !inside;
  }
  return inside;
}

/// Bounding box `[south, west, north, east]` across every ring of every
/// feature — used to fit the camera to a district and to cap how far the
/// map can be panned/zoomed away from it. Returns null for an empty/malformed
/// collection.
List<double>? geoJsonFeatureCollectionBounds(Map<String, dynamic> featureCollection) {
  final features = featureCollection['features'];
  if (features is! List) return null;
  double? south, west, north, east;
  for (final feature in features) {
    if (feature is! Map<String, dynamic>) continue;
    final geometry = feature['geometry'];
    if (geometry is! Map<String, dynamic>) continue;
    final type = geometry['type'];
    final coordinates = geometry['coordinates'];
    if (coordinates is! List) continue;
    final polygons = type == 'MultiPolygon' ? coordinates : [coordinates];
    for (final polygon in polygons) {
      if (polygon is! List) continue;
      for (final ring in polygon) {
        if (ring is! List) continue;
        for (final point in ring) {
          if (point is! List || point.length < 2) continue;
          final lng = (point[0] as num).toDouble(), lat = (point[1] as num).toDouble();
          south = south == null ? lat : (lat < south ? lat : south);
          north = north == null ? lat : (lat > north ? lat : north);
          west = west == null ? lng : (lng < west ? lng : west);
          east = east == null ? lng : (lng > east ? lng : east);
        }
      }
    }
  }
  if (south == null || west == null || north == null || east == null) return null;
  return [south, west, north, east];
}

bool _isPointInRing(double lat, double lng, List ring) {
  var inside = false;
  for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final pi = ring[i] as List;
    final pj = ring[j] as List;
    final xi = (pi[0] as num).toDouble(), yi = (pi[1] as num).toDouble();
    final xj = (pj[0] as num).toDouble(), yj = (pj[1] as num).toDouble();
    final intersects = ((yi > lat) != (yj > lat)) &&
        (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi);
    if (intersects) inside = !inside;
  }
  return inside;
}
