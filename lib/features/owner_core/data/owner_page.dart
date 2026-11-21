import '../json/owner_json.dart';

class OwnerPage<T> {
  const OwnerPage({this.items = const [], this.nextCursor});

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;

  static OwnerPage<T> fromJson<T>(Object? raw, T Function(Map<String, dynamic>) parse) {
    final m = OwnerJson.map(raw);
    return OwnerPage<T>(items: OwnerJson.list(m['items'], parse), nextCursor: OwnerJson.strOrNull(m['nextCursor']));
  }

  static List<T> appendNew<T>(List<T> current, List<T> page, String Function(T) idOf) {
    final seen = {for (final x in current) idOf(x)};
    return [...current, for (final x in page) if (seen.add(idOf(x))) x];
  }
}
