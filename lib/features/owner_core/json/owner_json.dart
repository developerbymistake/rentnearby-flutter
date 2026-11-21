import '../../buddy/shared/buddy_json.dart';

abstract final class OwnerJson {
  static Map<String, dynamic> map(Object? v) => BuddyJson.map(v);

  static Map<String, dynamic>? mapOrNull(Object? v) => BuddyJson.mapOrNull(v);

  static String str(Object? v, [String fallback = '']) => BuddyJson.str(v, fallback);

  static String? strOrNull(Object? v) => v is String && v.isNotEmpty ? v : null;

  static int integer(Object? v, [int fallback = 0]) => BuddyJson.integer(v, fallback);

  static int? intOrNull(Object? v) => BuddyJson.intOrNull(v);

  static double? doubleOrNull(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

  static bool boolean(Object? v, [bool fallback = false]) => BuddyJson.boolean(v, fallback);

  static bool? boolOrNull(Object? v) => v is bool ? v : (v == 'true' ? true : (v == 'false' ? false : null));

  static DateTime? time(Object? v) => BuddyJson.time(v);

  static List<T> list<T>(Object? v, T Function(Map<String, dynamic>) parse) => BuddyJson.list(v, parse);

  static List<String> strings(Object? v) => BuddyJson.strings(v);

  static List<int> ints(Object? v) => v is List ? [for (final e in v) if (e is num) e.toInt()] : const <int>[];

  static T pick<T>(Object? v, Map<String, T> values, T fallback) => BuddyJson.pick(v, values, fallback);
}
