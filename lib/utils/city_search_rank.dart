import 'search_fold.dart';

class _FoldedKeys {
  final String name;
  final String district;
  const _FoldedKeys(this.name, this.district);
}

// One city ranking for every city search: exact, prefix, word prefix, contains, district; state is never free text.
class CitySearchRank {
  CitySearchRank._();

  static const int exact = 0;
  static const int prefix = 1;
  static const int wordPrefix = 2;
  static const int contains = 3;
  static const int district = 4;
  static const int none = -1;

  static final Expando<_FoldedKeys> _cache = Expando<_FoldedKeys>('citySearchKeys');

  static int tier(String foldedName, String foldedQuery, [String foldedDistrict = '']) {
    if (foldedQuery.isEmpty) return none;
    if (foldedName == foldedQuery) return exact;
    if (foldedName.startsWith(foldedQuery)) return prefix;
    if (foldedName.contains(' $foldedQuery')) return wordPrefix;
    if (foldedName.contains(foldedQuery)) return contains;
    if (foldedDistrict.isNotEmpty && foldedDistrict.contains(foldedQuery)) return district;
    return none;
  }

  static List<T> rank<T extends Object>(
    Iterable<T> items,
    String query, {
    required String Function(T) name,
    String Function(T)? districtOf,
    bool Function(T)? popular,
    int Function(T)? weight,
  }) {
    final q = SearchFold.fold(query);
    if (q.isEmpty) return List.of(items);
    final hits = <(int, int, T, _FoldedKeys)>[];
    var i = 0;
    for (final item in items) {
      final keys = _keys(item, name, districtOf);
      final t = tier(keys.name, q, keys.district);
      if (t != none) hits.add((t, i, item, keys));
      i++;
    }
    hits.sort((a, b) {
      var c = a.$1.compareTo(b.$1);
      if (c != 0) return c;
      if (popular != null) {
        c = (popular(a.$3) ? 0 : 1).compareTo(popular(b.$3) ? 0 : 1);
        if (c != 0) return c;
      }
      if (weight != null) {
        c = weight(b.$3).compareTo(weight(a.$3));
        if (c != 0) return c;
      }
      c = a.$4.name.compareTo(b.$4.name);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    return [for (final h in hits) h.$3];
  }

  static _FoldedKeys _keys<T extends Object>(T item, String Function(T) name, String Function(T)? districtOf) {
    final hit = _cache[item];
    if (hit != null) return hit;
    final keys = _FoldedKeys(SearchFold.fold(name(item)), districtOf == null ? '' : SearchFold.fold(districtOf(item)));
    _cache[item] = keys;
    return keys;
  }
}
