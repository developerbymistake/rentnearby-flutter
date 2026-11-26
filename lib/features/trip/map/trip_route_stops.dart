import 'dart:collection';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'discovery_api.dart';
import 'discovery_geojson.dart';
import 'trip_marker_images.dart';

class RouteStop {
  final int day;
  final int index;
  final int number;
  final DiscoverySpot spot;
  final Color ring;

  const RouteStop({required this.day, required this.index, required this.number, required this.spot, required this.ring});

  String key(bool photo, [String size = '']) => '${spot.id}|${photo ? spot.thumbUrl : ''}|${ring.toARGB32()}|$number|$size';
}

/// The planned stops of the trip map as one symbol layer above the route lines: the shown day as full photo stops,
/// every other stop as a small dot in its day colour (one shared image per colour).
class TripRouteStops {
  static const String sourceId = 'trip-stops';
  static const String layerId = 'trip-stops-icons';
  static const String imagePrefix = 'trip-stop-';
  static const String dotPrefix = 'trip-stop-dot-';
  static const String kindKey = 'k';
  static const String kindFull = 'p';
  static const String kindDot = 'd';
  static const int fullLift = 1000;
  static const String _unknown = '';
  static const double minScale = 36 / 44;
  @visibleForTesting
  static const int cacheMax = 120;

  final DiscTuning tuning;
  final TripMarkerImages _images;
  final CanvasMarkerPainter painter;
  final LinkedHashMap<String, Uint8List> _png = LinkedHashMap();
  final Map<int, String> _sent = {};
  final Set<int> _dotsSent = {};
  final Map<int, Uint8List> _dotPng = {};
  Uint8List? _blank;
  List<RouteStop> _stops = const [];
  List<double> _opacity = const [];
  int? _fullDay;
  bool _drawn = false;
  int _gen = 0;

  TripRouteStops({DiscTuning? tuning, TripMarkerImages? images, this.painter = const CanvasMarkerPainter()})
      : tuning = tuning ?? DiscTuning.tripStops,
        _images = images ?? TripMarkerImages();

  List<RouteStop> get stops => _stops;

  int? get fullDay => _fullDay;

  /// Slots that hold a full stop image right now (the others were cleared or never sent).
  @visibleForTesting
  Set<int> get fullSlots => {..._sent.keys};

  Object get iconSize => tuning.stopIconSize(minScale);

  Object get layerIconSize => tuning.stopLayerIconSize(minScale, kindKey: kindKey, dotKind: kindDot);

  // Outer radius of the day ring at zoom 14, the room a camera fit leaves around the first and last stop.
  double get reachDp {
    final mid = (tuning.photoMidDp ?? tuning.photoDp) / tuning.photoDp;
    return (tuning.photoDp / 2 + CanvasMarkerPainter.stopRingDp(tuning)) * mid;
  }

  // With no full day every stop is a dot, so the fit only needs the dot radius at zoom 14.
  double reachFor(int? fullDay) => fullDay == null ? (tuning.dotMidDp ?? tuning.dotDp) / 2 : reachDp;

  SymbolLayerProperties get layerProps => SymbolLayerProperties(
        iconImage: ['get', 'img'],
        iconSize: layerIconSize,
        iconOpacity: ['get', 'op'],
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        symbolSortKey: ['get', 'n'],
      );

  static String imageOf(int i) => '$imagePrefix$i';

  static String dotImageOf(Color c) => '$dotPrefix${c.toARGB32()}';

  static bool isFull(RouteStop s, int? fullDay) => fullDay != null && s.day == fullDay;

  String get sizeKey => '${tuning.photoDp.toStringAsFixed(1)}_${(tuning.stopBadgeDp ?? 0).toStringAsFixed(1)}_${tuning.pxPerDp.toStringAsFixed(2)}';

  String keyOf(RouteStop s) => s.key(true, sizeKey);

  String plainKey(RouteStop s) => s.key(false, sizeKey);

  static Map<String, dynamic> geoJson(List<RouteStop> stops, List<double> opacity, {required int? fullDay}) => {
        'type': 'FeatureCollection',
        'features': [
          for (var i = 0; i < stops.length; i++)
            {
              'type': 'Feature',
              'id': i,
              'geometry': {
                'type': 'Point',
                'coordinates': [stops[i].spot.lon, stops[i].spot.lat],
              },
              'properties': <String, dynamic>{
                'img': isFull(stops[i], fullDay) ? imageOf(i) : dotImageOf(stops[i].ring),
                kindKey: isFull(stops[i], fullDay) ? kindFull : kindDot,
                'op': i < opacity.length ? opacity[i] : 1.0,
                'n': stops[i].number + (isFull(stops[i], fullDay) ? fullLift : 0),
              },
            },
        ],
      };

  RouteStop? at(Object? featureId) {
    final id = DiscGeoJson.featureId(featureId);
    final i = id == null ? null : int.tryParse(id);
    if (i == null || i < 0 || i >= _stops.length) return null;
    return _stops[i];
  }

  /// [fullDay] is the one day drawn as full photo stops; null draws every stop as a dot.
  Future<void> draw(MapLibreMapController map, List<RouteStop> stops, List<double> opacity, {String? below, required int? fullDay}) async {
    final gen = ++_gen;
    await _remove(map);
    _stops = stops;
    _opacity = [...opacity];
    _fullDay = fullDay;
    if (!await _register(map, gen)) return;
    if (stops.isNotEmpty) {
      await map.addSource(sourceId, GeojsonSourceProperties(data: geoJson(stops, _opacity, fullDay: fullDay)));
      await map.addSymbolLayer(sourceId, layerId, layerProps, belowLayerId: below, enableInteraction: true);
      _drawn = true;
    }
    if (!await _clearUnused(map, gen)) return;
    _loadPhotos(map, gen).ignore();
  }

  /// A day pick: dims as before and, when the full day changes, swaps the full images and keeps one source update.
  Future<void> setOpacity(MapLibreMapController map, List<double> opacity, {required int? fullDay}) async {
    if (!_drawn) return;
    if (fullDay == _fullDay) {
      if (listEquals(opacity, _opacity)) return;
      _opacity = [...opacity];
      await map.setGeoJsonSource(sourceId, geoJson(_stops, _opacity, fullDay: _fullDay));
      return;
    }
    final gen = ++_gen;
    _opacity = [...opacity];
    _fullDay = fullDay;
    if (!await _register(map, gen)) return;
    await map.setGeoJsonSource(sourceId, geoJson(_stops, _opacity, fullDay: fullDay));
    if (!await _clearUnused(map, gen)) return;
    _loadPhotos(map, gen).ignore();
  }

  void dispose() => _gen++;

  /// A new style drops every image; call it from the style-loaded callback.
  void resetImages() {
    _sent.clear();
    _dotsSent.clear();
  }

  String? _sentAt(int i) => _sent[i];

  bool _full(int i) => isFull(_stops[i], _fullDay);

  // Full images of the shown day from the PNG cache (or the plain icon stop), one dot image per day colour.
  Future<bool> _register(MapLibreMapController map, int gen) async {
    for (var i = 0; i < _stops.length; i++) {
      final s = _stops[i];
      if (!_full(i)) {
        final c = s.ring.toARGB32();
        if (_dotsSent.contains(c)) continue;
        final png = _dotPng[c] ??= await painter.dot(s.ring, tuning);
        if (gen != _gen) return false;
        await map.addImage(dotImageOf(s.ring), png);
        _dotsSent.add(c);
        if (gen != _gen) return false;
        continue;
      }
      final photo = keyOf(s);
      final key = _sentAt(i) == photo || _png.containsKey(photo) ? photo : plainKey(s);
      if (_sentAt(i) == key) continue;
      final png = _png[key] ?? await _render(s, null);
      if (gen != _gen) return false;
      await _send(map, i, key, png, gen);
      if (gen != _gen) return false;
    }
    return true;
  }

  // The plugin has no removeImage: a slot that is no longer shown is overwritten by a 1 px image, so its texture is freed.
  Future<bool> _clearUnused(MapLibreMapController map, int gen) async {
    final stale = [
      for (final i in _sent.keys)
        if (i >= _stops.length || !_full(i)) i,
    ];
    if (stale.isEmpty) return true;
    final blank = _blank ??= await painter.blank();
    for (final i in stale) {
      if (gen != _gen) return false;
      _sent.remove(i);
      await map.addImage(imageOf(i), blank);
    }
    return gen == _gen;
  }

  // A slot whose content is not known is kept as unknown, so it is sent again or cleared, never left full.
  Future<void> _send(MapLibreMapController map, int i, String key, Uint8List png, int gen) async {
    _sent[i] = _unknown;
    await map.addImage(imageOf(i), png);
    if (gen == _gen) _sent[i] = key;
  }

  Future<void> _remove(MapLibreMapController map) async {
    if (!_drawn) return;
    _drawn = false;
    try {
      await map.removeLayer(layerId);
    } catch (_) {}
    try {
      await map.removeSource(sourceId);
    } catch (_) {}
  }

  Future<void> _loadPhotos(MapLibreMapController map, int gen) async {
    final todo = [
      for (var i = 0; i < _stops.length; i++)
        if (_full(i) && _stops[i].spot.hasThumb && _sentAt(i) != keyOf(_stops[i])) i,
    ];
    final step = tuning.maxDownloads < 1 ? 1 : tuning.maxDownloads;
    for (var k = 0; k < todo.length; k += step) {
      final chunk = todo.sublist(k, k + step > todo.length ? todo.length : k + step);
      await Future.wait([
        for (final i in chunk)
          () async {
            try {
              final s = _stops[i];
              final key = keyOf(s);
              final cached = _png[key];
              final thumb = cached == null ? await _images.thumb(s.spot) : null;
              if ((cached == null && thumb == null) || gen != _gen) return;
              final png = cached ?? await _render(s, thumb);
              if (gen != _gen) return;
              await _send(map, i, key, png, gen);
            } catch (_) {}
          }(),
      ]);
      if (gen != _gen) return;
    }
  }

  Future<Uint8List> _render(RouteStop s, Uint8List? thumb) async {
    final png = await painter.stop(thumb: thumb, category: s.spot.category, ring: s.ring, number: s.number, t: tuning);
    final key = thumb != null ? keyOf(s) : plainKey(s);
    _png.remove(key);
    _png[key] = png;
    while (_png.length > cacheMax) {
      _png.remove(_png.keys.first);
    }
    return png;
  }
}
