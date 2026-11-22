import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:get_storage/get_storage.dart';

import '../pack/map_pack_constants.dart';

abstract final class MapPackStore {
  static const String metaKey = 'meta';
  static const String bodyPrefix = 'pack:';
  static const String versionPrefix = 'ver:';

  static GetStorage? _override;
  static Future<bool>? _init;

  static bool get _ready => _override != null;

  static GetStorage? get _box => _override;

  static Future<void> init() async {
    if (_override != null) return;
    final ok = await (_init ??= _open());
    if (ok && _override == null) _override = GetStorage(MapPackConstants.box);
  }

  static Future<bool> _open() async {
    try {
      await GetStorage.init(MapPackConstants.box);
      return true;
    } catch (_) {
      _init = null;
      return false;
    }
  }

  @visibleForTesting
  static void debugUseBox(GetStorage? box) {
    _override = box;
    _init = null;
  }

  static bool get isReady => _ready;

  static Map<String, dynamic>? readMeta() {
    final box = _box;
    if (box == null) return null;
    try {
      final raw = box.read<Object?>(metaKey);
      if (raw == null) return null;
      if (raw is String) {
        final v = jsonDecode(raw);
        if (v is Map<String, dynamic>) return v;
      }
    } catch (_) {}
    erase();
    return null;
  }

  static void writeMeta(Map<String, dynamic> meta) => _write(metaKey, _encode(meta));

  static String? readBody(String stateId) => _readString('$bodyPrefix$stateId', stateId);

  static String? readVersion(String stateId) => _readString('$versionPrefix$stateId', stateId);

  static void save(String stateId, String version, String raw) {
    _write('$bodyPrefix$stateId', raw);
    _write('$versionPrefix$stateId', version);
  }

  static void stampVersion(String stateId, String version) => _write('$versionPrefix$stateId', version);

  static void drop(String stateId) {
    final box = _box;
    if (box == null) return;
    try {
      box.remove('$bodyPrefix$stateId');
      box.remove('$versionPrefix$stateId');
    } catch (_) {}
  }

  static List<String> storedStates() {
    final box = _box;
    if (box == null) return const [];
    try {
      return [
        for (final k in box.getKeys<Iterable<dynamic>>().whereType<String>())
          if (k.startsWith(bodyPrefix) && k.length > bodyPrefix.length) k.substring(bodyPrefix.length),
      ];
    } catch (_) {
      return const [];
    }
  }

  static void erase() {
    final box = _box;
    if (box == null) return;
    try {
      box.erase();
    } catch (_) {}
  }

  static String? _encode(Map<String, dynamic> v) {
    try {
      return jsonEncode(v);
    } catch (_) {
      return null;
    }
  }

  static String? _readString(String key, String stateId) {
    final box = _box;
    if (box == null) return null;
    try {
      final v = box.read<Object?>(key);
      if (v == null) return null;
      if (v is String && v.isNotEmpty) return v;
    } catch (_) {}
    drop(stateId);
    return null;
  }

  static void _write(String key, String? value) {
    final box = _box;
    if (box == null || value == null) return;
    try {
      if (box.read<Object?>(key) == value) return;
      box.write(key, value);
    } catch (_) {}
  }
}
