import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import '../models/trip_spot_model.dart';

class TripSpotsCache {
  TripSpotsCache._();

  static const String container = 'trip_spots';
  static const Duration ttl = Duration(hours: 24);
  static const int maxItems = 300;
  static const String _legacyPrefix = 'trip_spots_list_cache_';

  static GetStorage? _box;

  static GetStorage? get box => _box;

  static Future<void> init() async {
    try {
      await GetStorage.init(container);
      _box = GetStorage(container);
      _dropLegacy(GetStorage());
    } catch (_) {}
  }

  @visibleForTesting
  static void debugUseBox(GetStorage? box) => _box = box;

  static void _dropLegacy(GetStorage legacy) {
    try {
      final keys = legacy.getKeys<Iterable<dynamic>>().whereType<String>().where((k) => k.startsWith(_legacyPrefix)).toList();
      for (final k in keys) {
        legacy.remove(k);
      }
    } catch (_) {}
  }

  static String _key(int cityKey) => 'c:$cityKey';

  static void save(int cityKey, List<TripSpotModel> items, String version) {
    final box = _box;
    if (box == null || items.isEmpty) return;
    try {
      box.write(_key(cityKey), encode(items, DateTime.now(), version: version)).ignore();
    } catch (_) {}
  }

  static List<TripSpotModel>? load(int cityKey) => _read(cityKey)?.items;

  static String? versionOf(int cityKey) => _read(cityKey)?.version;

  static ({List<TripSpotModel> items, String version})? _read(int cityKey) {
    try {
      final raw = _box?.read<Object?>(_key(cityKey));
      return decodeEntry(raw is String ? raw : null, DateTime.now());
    } catch (_) {
      return null;
    }
  }

  static void clear() {
    try {
      _box?.erase().ignore();
    } catch (_) {}
  }

  static String encode(List<TripSpotModel> items, DateTime now, {String version = ''}) => jsonEncode({
        't': now.millisecondsSinceEpoch,
        'v': version,
        'items': [for (final s in items.take(maxItems)) s.toJson()],
      });

  static List<TripSpotModel>? decode(String? raw, DateTime now) => decodeEntry(raw, now)?.items;

  static ({List<TripSpotModel> items, String version})? decodeEntry(String? raw, DateTime now) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final t = map['t'];
      if (t is! num) return null;
      final age = now.difference(DateTime.fromMillisecondsSinceEpoch(t.toInt()));
      if (age.isNegative || age > ttl) return null;
      final v = map['v'];
      final rows = map['items'];
      final list = [
        if (rows is List)
          for (final e in rows) ?TripSpotModel.tryFromJson(e),
      ];
      return list.isEmpty ? null : (items: list, version: v is String ? v : '');
    } catch (_) {
      return null;
    }
  }
}
