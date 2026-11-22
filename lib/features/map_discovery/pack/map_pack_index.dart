import 'dart:math' as math;

import 'map_pack_models.dart';

class MapPackIndex {
  final List<MapPackSpot> ranked;
  final Map<String, MapPackSpot> _byId;
  final Map<int, List<MapPackSpot>> _byCity;
  final List<String> stateIds;

  MapPackIndex._(this.ranked, this._byId, this._byCity, this.stateIds);

  static final MapPackIndex empty = MapPackIndex.of(const []);

  factory MapPackIndex.of(Iterable<MapPack> packs) {
    final byId = <String, MapPackSpot>{};
    final states = <String>[];
    for (final p in packs) {
      if (!states.contains(p.stateId)) states.add(p.stateId);
      for (final s in p.spots) {
        byId.putIfAbsent(s.id, () => s);
      }
    }
    final ranked = byId.values.toList()..sort(compare);
    final byCity = <int, List<MapPackSpot>>{};
    for (final s in ranked) {
      final k = s.cityKey;
      if (k != null) (byCity[k] ??= <MapPackSpot>[]).add(s);
    }
    return MapPackIndex._(
      List.unmodifiable(ranked),
      byId,
      {for (final e in byCity.entries) e.key: List.unmodifiable(e.value)},
      List.unmodifiable(states),
    );
  }

  static int compare(MapPackSpot a, MapPackSpot b) {
    final r = a.rank.compareTo(b.rank);
    if (r != 0) return r;
    final n = a.name.compareTo(b.name);
    return n != 0 ? n : a.id.compareTo(b.id);
  }

  int get length => ranked.length;
  bool get isEmpty => ranked.isEmpty;

  MapPackSpot? byId(String id) => _byId[id];

  List<MapPackSpot> byCity(int cityKey) => _byCity[cityKey] ?? const [];

  List<MapPackSpot> forCities(Iterable<int> cityKeys) {
    final keys = cityKeys.toSet();
    if (keys.isEmpty) return const [];
    if (keys.length == 1) return byCity(keys.first);
    return [for (final s in ranked) if (s.cityKey != null && keys.contains(s.cityKey)) s];
  }

  List<MapPackSpot> near(double lat, double lon, double km) {
    if (!lat.isFinite || !lon.isFinite || !km.isFinite || km <= 0) return const [];
    return [for (final s in ranked) if (MapPackGeo.km(lat, lon, s.lat, s.lon) <= km) s];
  }
}

class MapPackGeo {
  static const double _earthKm = 6371.0088;

  static double km(double lat1, double lon1, double lat2, double lon2) {
    const rad = math.pi / 180;
    final dLat = (lat2 - lat1) * rad;
    final dLon = (lon2 - lon1) * rad;
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1 * rad) * math.cos(lat2 * rad) * math.pow(math.sin(dLon / 2), 2);
    return 2 * _earthKm * math.asin(math.min(1.0, math.sqrt(h)));
  }
}
