abstract final class BuddyJson {
  static Map<String, dynamic> map(Object? v) =>
      v is Map<String, dynamic> ? v : (v is Map ? Map<String, dynamic>.from(v) : const <String, dynamic>{});

  static Map<String, dynamic>? mapOrNull(Object? v) => v is Map ? map(v) : null;

  static String str(Object? v, [String fallback = '']) => v is String ? v : (v == null ? fallback : '$v');

  static String? strOrNull(Object? v) => v is String ? v : null;

  static String? photo(Object? raw) {
    if (raw is! String) return null;
    final t = raw.trim();
    return t.isEmpty ? null : t;
  }

  static int integer(Object? v, [int fallback = 0]) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? fallback : fallback);

  static int? intOrNull(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

  static double? doubleOrNull(Object? v) => v is num ? v.toDouble() : null;

  static bool boolean(Object? v, [bool fallback = false]) => v is bool ? v : (v == 'true' ? true : (v == 'false' ? false : fallback));

  static DateTime? time(Object? v) => v is String ? DateTime.tryParse(v)?.toUtc() : null;

  static DateTime? date(Object? v) {
    if (v is! String || v.length < 10) return null;
    final d = DateTime.tryParse(v.substring(0, 10));
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  static String? dateText(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String? timeText(DateTime? t) => t?.toUtc().toIso8601String();

  static List<T> list<T>(Object? v, T Function(Map<String, dynamic>) parse) =>
      v is List ? [for (final e in v) if (e is Map) parse(map(e))] : <T>[];

  static List<String> strings(Object? v) => v is List ? [for (final e in v) if (e is String) e] : const <String>[];

  static T pick<T>(Object? v, Map<String, T> values, T fallback) => v is String ? values[v] ?? fallback : fallback;
}
