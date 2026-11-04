import 'package:maplibre_gl/maplibre_gl.dart';

/// A single autocomplete suggestion from the self-hosted Photon search
/// service. Read-only/display model — never round-tripped back to any
/// backend, so no toJson.
class PlaceResult {
  final String name;
  final String subtitle;
  final LatLng latLng;
  final String? placeType;
  final String? osmValue;
  final String? district;
  final String? state;
  final List<double>? extent;

  PlaceResult({
    required this.name,
    required this.subtitle,
    required this.latLng,
    this.placeType,
    this.osmValue,
    this.district,
    this.state,
    this.extent,
  });

  static String? _clean(Object? v) {
    final s = (v as String?)?.trim();
    return s == null || s.isEmpty ? null : s;
  }

  static String _typeLabel(String? osmValue) {
    if (osmValue == null) return '';
    final s = osmValue.replaceAll('_', ' ');
    return '${s[0].toUpperCase()}${s.substring(1)}';
  }

  factory PlaceResult.fromFeature(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>? ?? {};
    final coords = (feature['geometry']?['coordinates'] as List?)?.cast<num>();
    // Photon/GeoJSON order is [lon, lat] — flipped here to LatLng(lat, lon).
    final lat = coords != null && coords.length >= 2 ? coords[1].toDouble() : 0.0;
    final lon = coords != null && coords.length >= 2 ? coords[0].toDouble() : 0.0;

    final name = props['name'] as String? ?? '';
    final district = _clean(props['county']) ?? _clean(props['district']);
    final state = _clean(props['state']);
    // Photon's `type` is unreliable; `osm_value` is the accurate OSM type tag.
    final osmValue = _clean(props['osm_value']);

    final area = [?district, ?state].join(', ');
    final subtitle = [_typeLabel(osmValue), area].where((s) => s.isNotEmpty).join(' · ');

    return PlaceResult(
      name: name,
      subtitle: subtitle,
      latLng: LatLng(lat, lon),
      placeType: osmValue,
      osmValue: osmValue,
      district: district,
      state: state,
      extent: (props['extent'] as List?)?.map((e) => (e as num).toDouble()).toList(),
    );
  }
}
