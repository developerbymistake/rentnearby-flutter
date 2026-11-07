import '../../../utils/search_fold.dart';
import '../models/trip_city_model.dart';

class TripPopularRoute {
  final String from;
  final String to;

  const TripPopularRoute(this.from, this.to);
}

class TripPopularRoutes {
  static const int maxShown = 6;

  static const List<TripPopularRoute> pairs = [
    TripPopularRoute('Haridwar', 'Badrinath'),
    TripPopularRoute('Haridwar', 'Kedarnath'),
    TripPopularRoute('Rishikesh', 'Badrinath'),
    TripPopularRoute('Nainital', 'Almora'),
    TripPopularRoute('Shimla', 'Manali'),
    TripPopularRoute('Dehradun', 'Mussoorie'),
  ];

  static TripCityModel? _find(Map<String, List<TripCityModel>> byName, String name) {
    final hits = byName[SearchFold.fold(name)];
    if (hits == null || hits.isEmpty) return null;
    for (final c in hits) {
      if (c.isPopularDestination) return c;
    }
    return hits.first;
  }

  static Map<String, List<TripCityModel>> _index(List<TripCityModel> catalog) {
    final m = <String, List<TripCityModel>>{};
    for (final c in catalog) {
      (m[SearchFold.fold(c.name)] ??= []).add(c);
    }
    return m;
  }

  static List<({TripCityModel from, TripCityModel to})> resolve(List<TripCityModel> catalog) {
    if (catalog.isEmpty) return const [];
    final byName = _index(catalog);
    final out = <({TripCityModel from, TripCityModel to})>[];
    for (final p in pairs) {
      final a = _find(byName, p.from);
      final b = _find(byName, p.to);
      if (a == null || b == null || a.cityKey == b.cityKey || !a.isReady || !b.isReady) continue;
      out.add((from: a, to: b));
      if (out.length >= maxShown) break;
    }
    return out;
  }

  static List<TripCityModel> nextStops(List<TripCityModel> catalog, int afterCityKey) {
    if (catalog.isEmpty) return const [];
    TripCityModel? after;
    for (final c in catalog) {
      if (c.cityKey == afterCityKey) {
        after = c;
        break;
      }
    }
    if (after == null) return const [];
    final from = SearchFold.fold(after.name);
    final byName = _index(catalog);
    final seen = <int>{afterCityKey};
    final out = <TripCityModel>[];
    for (final p in pairs) {
      if (SearchFold.fold(p.from) != from) continue;
      final c = _find(byName, p.to);
      if (c != null && seen.add(c.cityKey)) out.add(c);
    }
    return out;
  }
}
