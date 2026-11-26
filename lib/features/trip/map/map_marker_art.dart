import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bakhli/design/design.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The 3D type icon of a map marker: one mapping source and a decode-once cache.
abstract final class MapMarkerArt {
  static const String pin = ListingArt.roundPushpin;

  static final Map<String, Future<ui.Image?>> _decoded = {};
  static int _decodes = 0;

  static String assetFor(String? category) {
    final c = category?.trim().toLowerCase() ?? '';
    if (c.isEmpty || c == 'attraction') return pin;
    return TripSpotLook.assetOf(c);
  }

  /// Decoded once per (asset, px); the caller draws it and never disposes it.
  static Future<ui.Image?> image(String? category, int px) {
    final target = px < 1 ? 1 : px;
    final key = '${assetFor(category)}@$target';
    return _decoded[key] ??= _decode(assetFor(category), target).then((img) {
      if (img == null) _decoded.remove(key);
      return img;
    });
  }

  static Future<ui.Image?> _decode(String asset, int px) async {
    try {
      _decodes++;
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(Uint8List.sublistView(data), targetWidth: px);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static int get decodeCount => _decodes;

  @visibleForTesting
  static void debugReset() {
    for (final f in _decoded.values) {
      f.then((i) => i?.dispose()).ignore();
    }
    _decoded.clear();
    _decodes = 0;
  }
}
