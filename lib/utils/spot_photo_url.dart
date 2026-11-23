import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'cloudinary_host.dart';

enum SpotPhotoSize { marker, square, card, hero, full }

abstract final class SpotPhotoUrl {
  static const String _marker = '/image/upload/';

  static const Map<SpotPhotoSize, String> transforms = {
    SpotPhotoSize.marker: 'c_fill,w_96,h_96,q_auto,f_auto',
    SpotPhotoSize.square: 'c_fill,g_auto,w_320,h_320,q_auto,f_auto',
    SpotPhotoSize.card: 'c_fill,g_auto,w_720,h_400,q_auto,f_auto',
    SpotPhotoSize.hero: 'c_fill,g_auto,w_1080,h_640,q_auto,f_auto',
    SpotPhotoSize.full: 'c_limit,w_1280,q_auto,f_auto',
  };

  static const Map<SpotPhotoSize, int> _widths = {
    SpotPhotoSize.marker: 96,
    SpotPhotoSize.square: 320,
    SpotPhotoSize.card: 720,
    SpotPhotoSize.hero: 1080,
    SpotPhotoSize.full: 1280,
  };

  static String? of(String? url, SpotPhotoSize size) {
    if (url == null || url.isEmpty) return url;
    if (!isCloudinaryHost(url)) return url;
    final i = url.indexOf(_marker);
    if (i < 0) return url;
    final at = i + _marker.length;
    final rest = url.substring(at);
    if (rest.startsWith('c_') || rest.startsWith('w_') || rest.startsWith('f_') || rest.startsWith('q_') || rest.startsWith('g_')) return url;
    return '${url.substring(0, at)}${transforms[size]}/$rest';
  }

  static int pixelWidth(SpotPhotoSize size) => _widths[size]!;

  static int cacheWidth(BuildContext context, double logicalWidth, SpotPhotoSize size) {
    final max = pixelWidth(size);
    if (!logicalWidth.isFinite) return max;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    return math.max(1, math.min((logicalWidth * dpr).ceil(), max));
  }
}
