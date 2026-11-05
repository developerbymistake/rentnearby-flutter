// One page of a keyset list (server `{items, hasMore, nextCursor}`); load more sends `cursor`, never an offset.
class KeysetPage<T> {
  final List<T> items;
  final String? nextCursor;
  final bool keyset;
  final bool? hasMoreField;

  const KeysetPage({required this.items, this.nextCursor, this.keyset = true, this.hasMoreField});

  static KeysetPage<T> parse<T>(Object? data, T Function(Map<String, dynamic>) item) {
    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    final raw = map['items'];
    final items = raw is List ? raw.whereType<Map<String, dynamic>>().map(item).toList() : <T>[];
    final cursor = map['nextCursor'];
    final more = map['hasMore'];
    return KeysetPage(
      items: items,
      nextCursor: cursor is String && cursor.isNotEmpty ? cursor : null,
      keyset: map.containsKey('nextCursor'),
      hasMoreField: more is bool ? more : null,
    );
  }

  // A keyset server has more exactly when it sent a cursor; an old server by its hasMore, else by a full page.
  bool hasMoreAfter(int limit) => keyset ? nextCursor != null : (hasMoreField ?? items.length >= limit);

  // The query of the next page: the cursor; an old server without one falls back to the loaded count.
  static Map<String, dynamic> nextParams({required String? cursor, required int loaded, required int limit}) =>
      cursor != null ? {'cursor': cursor, 'limit': limit} : {'offset': loaded, 'limit': limit};

  // Rows of the page not already shown, in order; a row the list already holds keeps its place.
  static List<T> appendNew<T>(List<T> current, List<T> page, String Function(T) idOf) {
    final seen = {for (final x in current) idOf(x)};
    return [
      for (final x in page)
        if (seen.add(idOf(x))) x,
    ];
  }
}
