import 'dart:convert';

import '../../map_discovery/pack/map_pack_models.dart';
import 'discovery_ids.dart';
import 'discovery_tiers.dart';

enum DiscSelKind { photo, badge, dot, planned }

class DiscFeatureRef {
  final String id;
  final double lat;
  final double lon;

  const DiscFeatureRef(this.id, this.lat, this.lon);
}

class DiscGeoJson {
  static Map<String, dynamic> get empty => {'type': 'FeatureCollection', 'features': <Object>[]};

  static Map<String, dynamic> all(Iterable<MapPackSpot> spots, Map<String, int> tiers) {
    final seen = <String>{};
    return _collection([
      for (final s in spots)
        if (seen.add(s.id)) _feature(s, tier: tiers[s.id] ?? DiscTiers.dot),
    ]);
  }

  static Map<String, dynamic> photo(Iterable<MapPackSpot> spots, Set<String> registeredIds, {Map<String, int>? tiers}) {
    final seen = <String>{};
    return _collection([
      for (final s in spots)
        if (registeredIds.contains(s.id) && seen.add(s.id))
          _feature(s, tier: tiers?[s.id] ?? DiscTiers.photo, img: DiscIds.photoImage(s.id)),
    ]);
  }

  static Map<String, dynamic> sel(MapPackSpot spot, DiscSelKind kind, {String? img, int? tier}) {
    final image = img ??
        switch (kind) {
          DiscSelKind.photo => DiscIds.photoImage(spot.id),
          DiscSelKind.badge => DiscIds.badgeImage(spot.category),
          _ => null,
        };
    final f = _feature(spot, tier: tier ?? _tierOfKind(kind), img: image);
    (f['properties'] as Map<String, dynamic>)['kind'] = kind.name;
    return _collection([f]);
  }

  static List<Object>? plannedFilter(Iterable<String> ids) {
    final list = ids.toSet().toList()..sort();
    if (list.isEmpty) return null;
    return [
      '!',
      [
        'in',
        ['id'],
        ['literal', list],
      ],
    ];
  }

  static List<Object>? layerFilter(String layerId, Iterable<String> plannedIds) {
    final planned = plannedFilter(plannedIds);
    if (layerId == DiscIds.layerBadge) {
      return planned == null ? DiscLayers.badgeTierFilter : ['all', DiscLayers.badgeTierFilter, planned];
    }
    return planned;
  }

  static List<DiscFeatureRef> refsOf(Iterable<Object?> raw) {
    final out = <DiscFeatureRef>[];
    for (final r in raw) {
      final f = _asMap(r);
      if (f == null) continue;
      final props = f['properties'];
      final id = _id(f['id']) ?? (props is Map ? _id(props['id']) : null);
      final geom = f['geometry'];
      final coords = geom is Map ? geom['coordinates'] : null;
      if (id == null || coords is! List || coords.length < 2) continue;
      final lon = coords[0], lat = coords[1];
      if (lon is! num || lat is! num || !lon.isFinite || !lat.isFinite) continue;
      out.add(DiscFeatureRef(id, lat.toDouble(), lon.toDouble()));
    }
    return out;
  }

  static String? nearest(Iterable<({String id, double x, double y})> points, double x, double y) {
    String? best;
    var bestD = double.infinity;
    for (final p in points) {
      if (!p.x.isFinite || !p.y.isFinite) continue;
      final dx = p.x - x, dy = p.y - y;
      final d = dx * dx + dy * dy;
      if (d < bestD || (d == bestD && best != null && p.id.compareTo(best) < 0)) {
        bestD = d;
        best = p.id;
      }
    }
    return best;
  }

  static String? featureId(Object? raw) => _id(raw);

  static int _tierOfKind(DiscSelKind k) => switch (k) {
        DiscSelKind.photo => DiscTiers.photo,
        DiscSelKind.badge => DiscTiers.badge,
        _ => DiscTiers.dot,
      };

  static Map<String, dynamic> _collection(List<Map<String, dynamic>> features) =>
      {'type': 'FeatureCollection', 'features': features};

  static Map<String, dynamic> _feature(MapPackSpot s, {required int tier, String? img}) => {
        'type': 'Feature',
        'id': s.id,
        'geometry': {
          'type': 'Point',
          'coordinates': [s.lon, s.lat],
        },
        'properties': <String, dynamic>{
          'cat': DiscIds.badgeKey(s.category),
          'grp': DiscTiers.groupOf(s.category),
          'rank': s.rank,
          'tier': tier,
          'img': ?img,
        },
      };

  static Map? _asMap(Object? r) {
    if (r is Map) return r;
    if (r is String) {
      try {
        final d = jsonDecode(r);
        return d is Map ? d : null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String? _id(Object? v) {
    if (v is String) return v.isEmpty ? null : v;
    if (v is int) return '$v';
    if (v is double && v.isFinite && v == v.truncateToDouble()) return '${v.toInt()}';
    return null;
  }
}
