import 'city_search_rank.dart';
import 'search_fold.dart';

// Photon order stays primary; place type only orders results that share a folded name.
class PlaceSearchRank {
  PlaceSearchRank._();

  static int typeRank(String? osmValue) => switch (osmValue) {
        'city' => 0,
        'town' => 1,
        'suburb' => 2,
        'village' => 3,
        _ => 4,
      };

  static int nameTier(String foldedName, String foldedQuery) {
    final t = CitySearchRank.tier(foldedName, foldedQuery);
    return t == CitySearchRank.none || t > CitySearchRank.wordPrefix ? CitySearchRank.contains : t;
  }

  static List<T> rank<T>(
    List<T> results,
    String query, {
    required String Function(T) name,
    required String? Function(T) state,
    required String? Function(T) type,
    String? preferState,
  }) {
    final q = SearchFold.fold(query);
    final prefer = preferState?.trim().toLowerCase();
    final rows = <(int, int, String, int, int, T)>[];
    for (var i = 0; i < results.length; i++) {
      final r = results[i];
      final s = state(r)?.trim().toLowerCase();
      final stateRank = prefer == null || prefer.isEmpty || s == prefer ? 0 : 1;
      final folded = SearchFold.fold(name(r));
      rows.add((q.isEmpty ? 0 : nameTier(folded, q), stateRank, folded, typeRank(type(r)), i, r));
    }
    final groupStart = <String, int>{};
    for (final row in rows) {
      groupStart.putIfAbsent('${row.$1}|${row.$2}|${row.$3}', () => row.$5);
    }
    int group((int, int, String, int, int, T) row) => groupStart['${row.$1}|${row.$2}|${row.$3}']!;
    rows.sort((a, b) {
      var c = a.$1.compareTo(b.$1);
      if (c == 0) c = a.$2.compareTo(b.$2);
      if (c == 0) c = group(a).compareTo(group(b));
      if (c == 0) c = a.$4.compareTo(b.$4);
      return c != 0 ? c : a.$5.compareTo(b.$5);
    });
    return [for (final row in rows) row.$6];
  }
}
