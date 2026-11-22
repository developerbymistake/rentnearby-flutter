import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/spot_gallery_loader.dart';
import '../models/trip_spot_model.dart';
import 'trip_spots_cache.dart';

abstract final class SpotGalleryCache {
  static const int maxMemory = 50;
  static const Duration ttl = TripSpotsCache.ttl;
  static const String _prefix = 'g:';

  static final LinkedHashMap<String, ({String version, DateTime at, SpotDetail detail})> _memory = LinkedHashMap();

  static String _id(int cityKey, String spotId) => '$cityKey:$spotId';

  static SpotDetail? get(int cityKey, String spotId, String version, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final id = _id(cityKey, spotId);
    final m = _memory.remove(id);
    if (m != null && m.version == version && _fresh(m.at, at)) {
      _memory[id] = m;
      return m.detail;
    }
    if (version.isEmpty) return null;
    final disk = _readDisk(id, version, at);
    if (disk != null) _remember(id, version, disk.at, disk.detail);
    return disk?.detail;
  }

  static void put(int cityKey, String spotId, String version, SpotDetail detail, {DateTime? now}) {
    final at = now ?? DateTime.now();
    final id = _id(cityKey, spotId);
    _remember(id, version, at, detail);
    if (version.isEmpty) return;
    try {
      TripSpotsCache.box?.write('$_prefix$id', jsonEncode({
        't': at.millisecondsSinceEpoch,
        'v': version,
        'urls': detail.gallery,
        if (detail.spot != null) 'spot': detail.spot!.toJson(),
      })).ignore();
    } catch (_) {}
  }

  static void clear() {
    _memory.clear();
    final box = TripSpotsCache.box;
    if (box == null) return;
    try {
      final keys = box.getKeys<Iterable<dynamic>>().whereType<String>().where((k) => k.startsWith(_prefix)).toList();
      for (final k in keys) {
        box.remove(k);
      }
    } catch (_) {}
  }

  static int get memoryLength => _memory.length;

  @visibleForTesting
  static void debugForgetMemory() => _memory.clear();

  static bool _fresh(DateTime saved, DateTime now) {
    final age = now.difference(saved);
    return !age.isNegative && age <= ttl;
  }

  static void _remember(String id, String version, DateTime at, SpotDetail detail) {
    _memory.remove(id);
    _memory[id] = (version: version, at: at, detail: detail);
    while (_memory.length > maxMemory) {
      _memory.remove(_memory.keys.first);
    }
  }

  static ({DateTime at, SpotDetail detail})? _readDisk(String id, String version, DateTime now) {
    try {
      final raw = TripSpotsCache.box?.read<Object?>('$_prefix$id');
      if (raw is! String) return null;
      final map = jsonDecode(raw);
      if (map is! Map || map['v'] != version) return null;
      final t = map['t'];
      if (t is! num) return null;
      final at = DateTime.fromMillisecondsSinceEpoch(t.toInt());
      if (!_fresh(at, now)) return null;
      return (
        at: at,
        detail: SpotDetail(
          spot: TripSpotModel.tryFromJson(map['spot']),
          gallery: TripSpotModel.cleanUrls(map['urls'], TripSpotModel.maxGallery),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}
