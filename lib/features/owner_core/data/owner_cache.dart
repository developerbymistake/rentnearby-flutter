import 'dart:convert';

import 'package:get_storage/get_storage.dart';

abstract final class OwnerCacheKeys {
  static const home = 'home';
  static const listing = 'listing';
  static const calUpcoming = 'cal_upcoming';
  static const calPast = 'cal_past';
  static const specialPrices = 'special_prices';
  static const blocks = 'blocks';
  static const planCard = 'plan_card';
  static const seekerFeed = 'seeker_feed';
  static String calMonth(String yyyyMM) => 'cal_month:$yyyyMM';
  static String summary(String yyyyMM) => 'summary:$yyyyMM';
  static String festivals(String stateName) => 'festivals:$stateName';

  static const List<String> listingScoped = [home, listing, calUpcoming, calPast, specialPrices, blocks, planCard];
  static const List<String> listingScopedPrefixes = ['cal_month:', 'summary:', 'festivals:'];
}

abstract final class OwnerCache {
  static const cachePrefix = 'owner_cache:';
  static const statusSeenPrefix = 'seeker_status_seen:';
  static const shellEmptyPrefix = 'owner_shell_empty:';

  static GetStorage? _boxOverride;
  static GetStorage get _box => _boxOverride ?? GetStorage();

  static void debugUseBox(GetStorage? box) => _boxOverride = box;

  static String _key(String userId, String key) => '$cachePrefix$userId:$key';

  static Map<String, dynamic>? read(String? userId, String key) {
    if (userId == null || userId.isEmpty) return null;
    try {
      final raw = _box.read<Object?>(_key(userId, key));
      if (raw is! String) return null;
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  static void write(String? userId, String key, Map<String, dynamic> json) {
    if (userId == null || userId.isEmpty) return;
    try {
      _box.write(_key(userId, key), jsonEncode(json));
    } catch (_) {}
  }

  static void remove(String? userId, String key) {
    if (userId == null || userId.isEmpty) return;
    try {
      _box.remove(_key(userId, key));
    } catch (_) {}
  }

  static void removeListingScoped(String? userId) {
    if (userId == null || userId.isEmpty) return;
    for (final k in OwnerCacheKeys.listingScoped) {
      remove(userId, k);
    }
    final base = '$cachePrefix$userId:';
    _removeWhere((k) => k.startsWith(base) && OwnerCacheKeys.listingScopedPrefixes.any((p) => k.startsWith('$base$p')));
  }

  static bool shellEmpty(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    try {
      return _box.read<Object?>('$shellEmptyPrefix$userId') == true;
    } catch (_) {
      return false;
    }
  }

  static void setShellEmpty(String? userId, bool value) {
    if (userId == null || userId.isEmpty) return;
    try {
      if (value) {
        _box.write('$shellEmptyPrefix$userId', true);
      } else {
        _box.remove('$shellEmptyPrefix$userId');
      }
    } catch (_) {}
  }

  static String? statusSeen(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    try {
      final v = _box.read<Object?>('$statusSeenPrefix$userId');
      return v is String ? v : null;
    } catch (_) {
      return null;
    }
  }

  static void setStatusSeen(String? userId, String key) {
    if (userId == null || userId.isEmpty) return;
    try {
      _box.write('$statusSeenPrefix$userId', key);
    } catch (_) {}
  }

  static void clearAll() =>
      _removeWhere((k) => k.startsWith(cachePrefix) || k.startsWith(statusSeenPrefix) || k.startsWith(shellEmptyPrefix));

  static void _removeWhere(bool Function(String key) test) {
    try {
      final keys = _box.getKeys<Iterable<dynamic>>().whereType<String>().where(test).toList();
      for (final k in keys) {
        _box.remove(k);
      }
    } catch (_) {}
  }
}
