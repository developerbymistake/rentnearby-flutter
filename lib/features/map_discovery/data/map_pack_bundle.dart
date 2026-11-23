import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import '../pack/map_pack_models.dart';
import '../pack/map_pack_parser.dart';
import 'map_pack_store.dart';

// The base packs shipped inside the app (assets/map_packs/). Used only on a fresh install, so the first map open
// already has its places and works offline; the normal version check replaces them with the newer server packs.
abstract final class MapPackBundle {
  static const String dir = 'assets/map_packs/';

  @visibleForTesting
  static bool disabled = false;

  static Future<List<MapPackRef>> seed() async {
    if (disabled) return const [];
    try {
      final manifest = jsonDecode(await rootBundle.loadString('${dir}manifest.json'));
      if (manifest is! Map) return const [];
      final files = {
        for (final e in (manifest['packs'] as List? ?? const []))
          if (e is Map && e['stateId'] is String && e['file'] is String) e['stateId'] as String: e['file'] as String,
      };
      final out = <MapPackRef>[];
      for (final ref in MapPackParser.refs(manifest)) {
        final file = files[ref.stateId];
        if (file == null) continue;
        final body = await rootBundle.loadString('$dir$file');
        if (body.isEmpty) continue;
        MapPackStore.save(ref.stateId, ref.version, body);
        out.add(ref);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
