import 'dart:convert';
import 'package:get_storage/get_storage.dart';
import '../models/trip_spot_model.dart';

class TripSpotsCache {
  TripSpotsCache._();

  static const Duration ttl = Duration(hours: 24);
  static const int maxItems = 300;
  static const String _prefix = 'trip_spots_list_cache_';

  static String _key(int cityKey) => '$_prefix$cityKey';

  static void save(int cityKey, List<TripSpotModel> items) {
    if (items.isEmpty) return;
    try {
      GetStorage().write(_key(cityKey), encode(items, DateTime.now())).ignore();
    } catch (_) {}
  }

  static List<TripSpotModel>? load(int cityKey) {
    try {
      final raw = GetStorage().read(_key(cityKey));
      return decode(raw is String ? raw : null, DateTime.now());
    } catch (_) {
      return null;
    }
  }

  static String encode(List<TripSpotModel> items, DateTime now) => jsonEncode({
        't': now.millisecondsSinceEpoch,
        'items': [for (final s in items.take(maxItems)) _toJson(s)],
      });

  static List<TripSpotModel>? decode(String? raw, DateTime now) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      final t = (map['t'] as num?)?.toInt();
      if (t == null) return null;
      final age = now.difference(DateTime.fromMillisecondsSinceEpoch(t));
      if (age.isNegative || age > ttl) return null;
      final list = [
        for (final e in (map['items'] as List? ?? const []))
          TripSpotModel.fromJson(Map<String, dynamic>.from(e as Map)),
      ];
      return list.isEmpty ? null : list;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _toJson(TripSpotModel s) => {
        'id': s.id,
        'source': s.source,
        'name': s.name,
        'displayName': s.displayName,
        'description': s.description,
        'latitude': s.latitude,
        'longitude': s.longitude,
        'category': s.category,
        'area': s.area,
        'visitMinutes': s.visitMinutes,
        'isFeatured': s.isFeatured,
        'rank': s.rank,
        'imageUrl': s.imageUrl,
        'images': s.images,
      };
}
