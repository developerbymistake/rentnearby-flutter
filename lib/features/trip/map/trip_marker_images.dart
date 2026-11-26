import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bakhli/design/design.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../utils/spot_photo_url.dart';
import '../models/trip_spot_category.dart';
import 'discovery_api.dart';
import 'map_marker_art.dart';
import 'map_marker_sizes.dart';

typedef MarkerFetch = Future<Uint8List?> Function(String url);

abstract class MarkerDiskStore {
  Future<Uint8List?> read(String key);
  Future<void> write(String key, Uint8List bytes);
  Future<int> count();
  Future<void> clear();
  Future<void> trimTo(int keep);
}

class DiscMarkerFolderStore implements MarkerDiskStore {
  static const String folder = 'disc_markers';
  final Directory Function() _root;

  DiscMarkerFolderStore({Directory Function()? root}) : _root = root ?? _systemCache;

  static Directory _systemCache() => Directory.systemTemp;

  Directory get _dir => Directory('${_root().path}${Platform.pathSeparator}$folder');

  File _file(String key) => File('${_dir.path}${Platform.pathSeparator}$key.png');

  @override
  Future<Uint8List?> read(String key) async {
    try {
      final f = _file(key);
      if (!await f.exists()) return null;
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    try {
      final dir = _dir;
      if (!await dir.exists()) await dir.create(recursive: true);
      await _file(key).writeAsBytes(bytes);
    } catch (_) {}
  }

  @override
  Future<int> count() async {
    try {
      final dir = _dir;
      if (!await dir.exists()) return 0;
      return await dir.list().length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<void> clear() async {
    try {
      final dir = _dir;
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  @override
  Future<void> trimTo(int keep) async {
    try {
      final dir = _dir;
      if (!await dir.exists()) return;
      final files = [
        for (final e in await dir.list().toList())
          if (e is File) (f: e, at: (await e.stat()).modified),
      ]..sort((a, b) => b.at.compareTo(a.at));
      for (final x in files.skip(keep < 0 ? 0 : keep)) {
        try {
          await x.f.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }
}

abstract class MarkerPainter {
  Future<Uint8List> badge(String category, DiscTuning t);
  Future<Uint8List> dot(Color color, DiscTuning t);
  Future<Uint8List?> photo(Uint8List thumb, DiscTuning t);
  Future<bool> valid(Uint8List png);
}

class CanvasMarkerPainter implements MarkerPainter {
  const CanvasMarkerPainter();

  static const double _ringBadge = 1.5;
  static const double _ringDot = 1;
  static const double _ringPhoto = 2;
  static const double _shadowPad = 3;
  static const double _artRatio = 0.64;

  static double canvasDp(double markerDp) => markerDp + _shadowPad * 2;

  @override
  Future<Uint8List> badge(String category, DiscTuning t) async {
    final size = t.px(canvasDp(t.badgeDp)).toDouble();
    final r = t.badgeDp * t.pxPerDp / 2;
    final c = Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
    _shadow(canvas, c, r, t);
    canvas.drawCircle(c, r, Paint()..color = TripSpotCategory.colorOf(DiscIds.badgeKey(category)));
    canvas.drawCircle(
      c,
      r - _ringBadge * t.pxPerDp / 2,
      Paint()
        ..color = FitnessAppTheme.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ringBadge * t.pxPerDp,
    );
    await _art(canvas, c, category, r * 2 * _artRatio);
    return _png(recorder, size);
  }

  // Dot drawn at the zoomed-in size with a 1 dp white ring, like the old circle layer, so it can collide as a symbol.
  @override
  Future<Uint8List> dot(Color color, DiscTuning t) async {
    final size = t.px(t.dotDp).toDouble();
    final r = t.dotDp * t.pxPerDp / 2;
    final ring = _ringDot * t.pxPerDp;
    final c = Offset(size / 2, size / 2);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
    canvas.drawCircle(c, r, Paint()..color = FitnessAppTheme.white);
    canvas.drawCircle(c, r - ring, Paint()..color = color);
    return _png(recorder, size);
  }

  @override
  Future<Uint8List?> photo(Uint8List thumb, DiscTuning t) async {
    ui.Image? src;
    try {
      final codec = await ui.instantiateImageCodec(thumb, targetWidth: t.thumbPx * 2, allowUpscaling: false);
      src = (await codec.getNextFrame()).image;
      codec.dispose();
    } catch (_) {
      return null;
    }
    try {
      final size = t.px(canvasDp(t.photoDp)).toDouble();
      final r = t.photoDp * t.pxPerDp / 2;
      final ring = _ringPhoto * t.pxPerDp;
      final c = Offset(size / 2, size / 2);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
      _shadow(canvas, c, r, t);
      canvas.drawCircle(c, r, Paint()..color = FitnessAppTheme.white);
      final side = src.width < src.height ? src.width : src.height;
      final from = Rect.fromLTWH((src.width - side) / 2, (src.height - side) / 2, side.toDouble(), side.toDouble());
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r - ring)));
      canvas.drawImageRect(src, from, Rect.fromCircle(center: c, radius: r - ring), Paint()..filterQuality = FilterQuality.high);
      canvas.restore();
      return await _png(recorder, size);
    } catch (_) {
      return null;
    } finally {
      src.dispose();
    }
  }

  static double stopRingDp([DiscTuning? t]) => DS.s(MapMarkerSizes.stopRing) * (t?.ringGrow ?? 1);
  static double stopBadgeDp(DiscTuning t) => t.stopBadgeDp ?? DS.s(20);
  static double stopBadgeRingDp(DiscTuning t) => _ringBadge * t.ringGrow;
  static double stopPhotoRingDp(DiscTuning t) => _ringPhoto * t.ringGrow;

  static double stopCanvasDp(DiscTuning t) {
    final outer = t.photoDp / 2 + stopRingDp(t);
    final corner = outer * _corner + stopBadgeDp(t) / 2 + _ringBadge;
    return 2 * (corner > outer + _shadowPad ? corner : outer + _shadowPad);
  }

  static const double _corner = 0.7071;

  // The image is drawn at the zoom-17 size and scaled down, so the number shows at caption size times the marker scale at zoom 14.
  static TextStyle stopNumberStyle(DiscTuning t) {
    final base = TypeTokens.caption;
    final grow = t.photoDp / (t.photoMidDp ?? t.photoDp);
    return base.copyWith(color: FitnessAppTheme.white, height: 1, fontSize: base.fontSize! * grow * t.sizeScale * t.pxPerDp);
  }

  // Pixel side of the photo circle inside the white ring, at the zoom-17 size the stop is drawn at.
  static int stopPhotoPx(DiscTuning t) => t.px(t.photoDp - 2 * stopPhotoRingDp(t));

  // Decode size that makes the shorter side cover the circle, never larger than that and never upscaled.
  static ({int width, int height}) coverSize(int width, int height, int side) {
    final short = width < height ? width : height;
    if (short <= side || short <= 0) return (width: width, height: height);
    final k = side / short;
    final w = (width * k).round(), h = (height * k).round();
    return (width: w < 1 ? 1 : w, height: h < 1 ? 1 : h);
  }

  static Future<ui.Image?> _decodeCover(Uint8List bytes, int side) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? d;
    try {
      d = await ui.ImageDescriptor.encoded(buffer);
      final size = coverSize(d.width, d.height, side);
      final codec = await d.instantiateCodec(targetWidth: size.width, targetHeight: size.height);
      try {
        return (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return null;
    } finally {
      d?.dispose();
      buffer.dispose();
    }
  }

  // A 1 px clear image that replaces a stop image the map no longer shows.
  Future<Uint8List> blank() {
    final recorder = ui.PictureRecorder();
    Canvas(recorder, const Rect.fromLTWH(0, 0, 1, 1));
    return _png(recorder, 1);
  }

  // Route stop: the spot photo (or its category icon) in the white ring, the day colour ring outside, the order badge on the corner.
  Future<Uint8List> stop({Uint8List? thumb, required String category, required Color ring, required int number, required DiscTuning t}) async {
    final src = thumb == null ? null : await _decodeCover(thumb, stopPhotoPx(t));
    try {
      final p = t.pxPerDp;
      final size = t.px(stopCanvasDp(t)).toDouble();
      final r = t.photoDp * p / 2;
      final outer = r + stopRingDp(t) * p;
      final c = Offset(size / 2, size / 2);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
      _shadow(canvas, c, outer, t);
      canvas.drawCircle(c, outer, Paint()..color = ring);
      canvas.drawCircle(c, r, Paint()..color = FitnessAppTheme.white);
      final inner = Rect.fromCircle(center: c, radius: r - stopPhotoRingDp(t) * p);
      final image = src;
      if (image != null) {
        final side = image.width < image.height ? image.width : image.height;
        final from = Rect.fromLTWH((image.width - side) / 2, (image.height - side) / 2, side.toDouble(), side.toDouble());
        canvas.save();
        canvas.clipPath(Path()..addOval(inner));
        canvas.drawImageRect(image, from, inner, Paint()..filterQuality = FilterQuality.high);
        canvas.restore();
      } else {
        canvas.drawCircle(c, inner.width / 2, Paint()..color = TripSpotCategory.colorOf(DiscIds.badgeKey(category)));
        await _art(canvas, c, category, inner.width * _artRatio);
      }
      final b = stopBadgeDp(t) * p / 2;
      final at = c + Offset(outer * _corner, -outer * _corner);
      canvas.drawCircle(at, b, Paint()..color = ring);
      final badgeRing = stopBadgeRingDp(t) * p;
      canvas.drawCircle(
        at,
        b - badgeRing / 2,
        Paint()
          ..color = FitnessAppTheme.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = badgeRing,
      );
      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(text: '$number', style: stopNumberStyle(t)),
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
      tp.dispose();
      return await _png(recorder, size);
    } finally {
      src?.dispose();
    }
  }

  static Future<void> _art(Canvas canvas, Offset c, String category, double side) async {
    final img = await MapMarkerArt.image(category, side.round());
    if (img == null) return;
    final to = Rect.fromCenter(center: c, width: side, height: side);
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), to, Paint()..filterQuality = FilterQuality.high);
  }

  @override
  Future<bool> valid(Uint8List png) async {
    if (png.length < 8 || png[0] != 0x89 || png[1] != 0x50 || png[2] != 0x4E || png[3] != 0x47) return false;
    try {
      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      final ok = frame.image.width > 0 && frame.image.height > 0;
      frame.image.dispose();
      codec.dispose();
      return ok;
    } catch (_) {
      return false;
    }
  }

  static void _shadow(Canvas canvas, Offset c, double r, DiscTuning t) {
    canvas.drawCircle(
      c + Offset(0, t.pxPerDp),
      r,
      Paint()
        ..color = FitnessAppTheme.grey.withValues(alpha: Alpha.scrim)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * t.pxPerDp),
    );
  }

  static Future<Uint8List> _png(ui.PictureRecorder recorder, double size) async {
    final img = await recorder.endRecording().toImage(size.round(), size.round());
    try {
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      img.dispose();
    }
  }
}

class TripMarkerImages {
  final MarkerFetch _fetch;
  final MarkerDiskStore _disk;
  final MarkerPainter _painter;

  TripMarkerImages({MarkerFetch? fetch, MarkerDiskStore? disk, MarkerPainter? painter})
      : _fetch = fetch ?? _defaultFetch,
        _disk = disk ?? DiscMarkerFolderStore(),
        _painter = painter ?? const CanvasMarkerPainter();

  static Future<void> clearDisk() => DiscMarkerFolderStore().clear();

  static Future<Uint8List?> _defaultFetch(String url) async {
    try {
      final file = await CachedNetworkImageProvider.defaultCacheManager.getSingleFile(url);
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static String thumbHash(String url) {
    var h = 0x811c9dc5;
    for (final c in url.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  static String cacheKey(String spotId, String thumbUrl, DiscTuning t) {
    final safe = spotId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final dpr = t.pxPerDp.toStringAsFixed(2).replaceAll('.', 'p');
    return '${safe}_${t.photoDp.round()}_${dpr}_${thumbHash(thumbUrl)}';
  }

  static String? markerUrl(DiscoverySpot s) => s.hasThumb ? SpotPhotoUrl.of(s.thumbUrl, SpotPhotoSize.marker) : null;

  Future<Uint8List> badge(String category, DiscTuning t) => _painter.badge(category, t);

  Future<Uint8List> dot(Color color, DiscTuning t) => _painter.dot(color, t);

  Future<Uint8List?> thumb(DiscoverySpot s) async {
    final url = markerUrl(s);
    if (url == null || url.isEmpty) return null;
    final bytes = await _fetch(url);
    return bytes == null || bytes.isEmpty ? null : bytes;
  }

  Future<Uint8List?> photoFor(DiscoverySpot s, DiscTuning t) async {
    final url = markerUrl(s);
    if (url == null || url.isEmpty) return null;
    final key = cacheKey(s.id, url, t);
    final cached = await _disk.read(key);
    if (cached != null && await _painter.valid(cached)) return cached;
    final thumb = await _fetch(url);
    if (thumb == null || thumb.isEmpty) return null;
    final png = await _painter.photo(thumb, t);
    if (png == null) return null;
    await _disk.write(key, png);
    return png;
  }

  Future<void> trimDisk(DiscTuning t) async {
    if (await _disk.count() > t.markerCacheMax) await _disk.trimTo(t.markerCacheMax * 2 ~/ 3);
  }

  Future<Set<String>> register({
    required List<DiscoverySpot> spots,
    required DiscTuning tuning,
    required Set<String> already,
    required Future<void> Function(String name, Uint8List bytes) addImage,
    required Future<void> Function(Set<String> registered) onBatch,
    required bool Function() alive,
    String Function(DiscoverySpot s)? nameOf,
  }) async {
    final registered = {...already};
    final todo = [for (final s in spots) if (s.hasThumb && !registered.contains(s.id)) s];
    if (todo.isEmpty) return registered;
    await trimDisk(tuning);
    final step = tuning.batch < 1 ? 1 : tuning.batch;
    for (var i = 0; i < todo.length; i += step) {
      if (!alive()) return registered;
      final chunk = todo.sublist(i, i + step > todo.length ? todo.length : i + step);
      final images = await _pool(chunk, tuning.maxDownloads, (s) => photoFor(s, tuning));
      var added = false;
      for (var k = 0; k < chunk.length; k++) {
        final png = images[k];
        if (png == null) continue;
        if (!alive()) return registered;
        try {
          await addImage(nameOf?.call(chunk[k]) ?? DiscIds.photoImage(chunk[k].id), png);
          registered.add(chunk[k].id);
          added = true;
        } catch (_) {}
      }
      if (!alive()) return registered;
      if (added) await onBatch({...registered});
    }
    return registered;
  }

  static Future<List<R?>> _pool<T, R>(List<T> items, int width, Future<R?> Function(T) run) async {
    final out = List<R?>.filled(items.length, null);
    var next = 0;
    Future<void> worker() async {
      while (next < items.length) {
        final i = next++;
        try {
          out[i] = await run(items[i]);
        } catch (_) {
          out[i] = null;
        }
      }
    }

    await Future.wait([for (var w = 0; w < (width < 1 ? 1 : width) && w < items.length; w++) worker()]);
    return out;
  }
}
