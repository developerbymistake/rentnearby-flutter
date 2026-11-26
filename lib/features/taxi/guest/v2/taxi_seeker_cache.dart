import 'dart:collection';

import '../../../owner_core/data/owner_cache.dart';
import '../../../owner_core/session/owner_session_hooks.dart';
import 'taxi_feed_repository.dart';
import 'taxi_popular_routes.dart';

class TaxiLocalCopy {
  final String date;
  final double lat;
  final double lng;
  final Map<String, dynamic> data;

  const TaxiLocalCopy({required this.date, required this.lat, required this.lng, required this.data});
}

class TaxiPopularCopy {
  final String date;
  final DateTime savedAt;
  final List<TaxiPopularRoute> routes;

  const TaxiPopularCopy({required this.date, required this.savedAt, required this.routes});
}

class _RouteEntry {
  final TaxiRouteFeed feed;
  final DateTime savedAt;

  const _RouteEntry(this.feed, this.savedAt);
}

abstract final class TaxiSeekerCache {
  static const localKey = 'taxi_feed_local';
  static const popularKey = 'taxi_popular_routes';
  static const routeFresh = Duration(minutes: 2);
  static const popularFresh = Duration(minutes: 5);
  static const routeEntries = 12;

  static final LinkedHashMap<String, _RouteEntry> _routes = LinkedHashMap();
  static TaxiPopularCopy? _popular;
  static String? _popularUser;

  static double round2(double v) => (v * 100).roundToDouble() / 100;

  static String routeKey({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    required String date,
    required String sort,
    TaxiCityPair? cities,
  }) =>
      '${fromLat.toStringAsFixed(3)},${fromLng.toStringAsFixed(3)}|${toLat.toStringAsFixed(3)},${toLng.toStringAsFixed(3)}|$date|$sort${cities == null ? '' : '|c$cities'}';

  static ({TaxiRouteFeed feed, bool fresh})? route(String key, DateTime now) {
    final e = _routes.remove(key);
    if (e == null) return null;
    _routes[key] = e;
    return (feed: e.feed, fresh: now.difference(e.savedAt) <= routeFresh);
  }

  static void putRoute(String key, TaxiRouteFeed feed, DateTime now) {
    _routes.remove(key);
    _routes[key] = _RouteEntry(feed, now);
    while (_routes.length > routeEntries) {
      _routes.remove(_routes.keys.first);
    }
  }

  static TaxiLocalCopy? readLocal(String? userId) {
    final raw = OwnerCache.read(userId, localKey);
    if (raw == null) return null;
    final date = raw['date'];
    final lat = raw['lat'];
    final lng = raw['lng'];
    final data = raw['data'];
    if (date is! String || lat is! num || lng is! num || data is! Map) return null;
    return TaxiLocalCopy(date: date, lat: lat.toDouble(), lng: lng.toDouble(), data: Map<String, dynamic>.from(data));
  }

  static void writeLocal(String? userId, {required String date, required double lat, required double lng, required Map<String, dynamic> data, required DateTime now}) {
    OwnerCache.write(userId, localKey, {
      'date': date,
      'lat': round2(lat),
      'lng': round2(lng),
      'savedAt': now.toIso8601String(),
      'data': data,
    });
  }

  static void dropLocal(String? userId) => OwnerCache.remove(userId, localKey);

  static TaxiPopularCopy? readPopular(String? userId) {
    final mem = _popular;
    if (mem != null && _popularUser == userId) return mem;
    final raw = OwnerCache.read(userId, popularKey);
    if (raw == null) return null;
    final date = raw['date'];
    final at = raw['savedAt'];
    final savedAt = at is String ? DateTime.tryParse(at) : null;
    if (date is! String || savedAt == null) return null;
    final copy = TaxiPopularCopy(date: date, savedAt: savedAt, routes: TaxiPopularRoute.listFrom(raw['items']));
    _popular = copy;
    _popularUser = userId;
    return copy;
  }

  static void writePopular(String? userId, {required String date, required List<TaxiPopularRoute> routes, required DateTime now}) {
    _popular = TaxiPopularCopy(date: date, savedAt: now, routes: routes);
    _popularUser = userId;
    OwnerCache.write(userId, popularKey, {
      'date': date,
      'savedAt': now.toIso8601String(),
      'items': [for (final r in routes) r.toJson()],
    });
  }

  static void clearMemory() {
    _routes.clear();
    _popular = null;
    _popularUser = null;
  }
}

abstract final class TaxiSeekerSession {
  static const String name = 'taxi_seeker';

  static void register() => OwnerSessionHooks.register(name, (_, _) => TaxiSeekerCache.clearMemory());
}
