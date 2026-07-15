import 'package:maplibre_gl/maplibre_gl.dart';

/// A single autocomplete suggestion from the self-hosted Photon search
/// service. Read-only/display model — never round-tripped back to any
/// backend, so no toJson.
class PlaceResult {
  final String name;
  final String subtitle;
  final LatLng latLng;
  final String? placeType;
  final List<double>? extent;

  PlaceResult({
    required this.name,
    required this.subtitle,
    required this.latLng,
    this.placeType,
    this.extent,
  });

  factory PlaceResult.fromFeature(Map<String, dynamic> feature) {
    final props = feature['properties'] as Map<String, dynamic>? ?? {};
    final coords = (feature['geometry']?['coordinates'] as List?)?.cast<num>();
    // Photon/GeoJSON order is [lon, lat] — flipped here to LatLng(lat, lon).
    final lat = coords != null && coords.length >= 2 ? coords[1].toDouble() : 0.0;
    final lon = coords != null && coords.length >= 2 ? coords[0].toDouble() : 0.0;

    final name = props['name'] as String? ?? '';
    final city = props['city'] as String?;
    final state = props['state'] as String?;
    final country = props['country'] as String?;

    final subtitleParts = <String>[
      if (city != null && city != name) city,
      ?state,
      ?country,
    ];

    return PlaceResult(
      name: name,
      subtitle: subtitleParts.join(', '),
      latLng: LatLng(lat, lon),
      // Photon's own `type` field is a coarse, unreliable bucket (e.g. a
      // suburb or hamlet can come back labeled "district", a school labeled
      // "house") — `osm_value` is the actual OSM value for the `place` key
      // our search is already scoped to (city/town/village/hamlet/suburb/
      // etc.), so it's the accurate source for the tag shown to the user.
      placeType: props['osm_value'] as String?,
      extent: (props['extent'] as List?)?.map((e) => (e as num).toDouble()).toList(),
    );
  }
}
