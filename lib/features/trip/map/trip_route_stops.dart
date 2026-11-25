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

  String key(bool photo) => '${spot.id}|${photo ? spot.thumbUrl : ''}|${ring.toARGB32()}|$number';
}

/// The planned stops of the trip map as one symbol layer: real spot circles that shrink with the zoom, above the route lines.
class TripRouteStops {
  static const String sourceId = 'trip-stops';
  static const String layerId = 'trip-stops-icons';
  static const String imagePrefix = 'trip-stop-';
  static const double minScale = 36 / 44;
  static const int _cacheMax = 120;

  final DiscTuning tuning;
  final TripMarkerImages _images;
  final CanvasMarkerPainter painter;
  final LinkedHashMap<String, Uint8List> _png = LinkedHashMap();
  List<RouteStop> _stops = const [];
  List<double> _opacity = const [];
  bool _drawn = false;
  int _gen = 0;

  TripRouteStops({DiscTuning? tuning, TripMarkerImages? images, this.painter = const CanvasMarkerPainter()})
      : tuning = tuning ?? DiscTuning.tripStops,
        _images = images ?? TripMarkerImages();

  List<RouteStop> get stops => _stops;

  Object get iconSize => tuning.stopIconSize(minScale);

  SymbolLayerProperties get layerProps => SymbolLayerProperties(
        iconImage: ['get', 'img'],
        iconSize: iconSize,
        iconOpacity: ['get', 'op'],
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        symbolSortKey: ['get', 'n'],
      );

  static String imageOf(int i) => '$imagePrefix$i';

  static Map<String, dynamic> geoJson(List<RouteStop> stops, List<double> opacity) => {
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
                'img': imageOf(i),
                'op': i < opacity.length ? opacity[i] : 1.0,
                'n': stops[i].number,
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

  Future<void> draw(MapLibreMapController map, List<RouteStop> stops, List<double> opacity, {String? below}) async {
    final gen = ++_gen;
    await _remove(map);
    _stops = stops;
    _opacity = [...opacity];
    if (stops.isEmpty) return;
    for (var i = 0; i < stops.length; i++) {
      final s = stops[i];
      final png = _png[s.key(true)] ?? await _render(s, null);
      if (gen != _gen) return;
      await map.addImage(imageOf(i), png);
    }
    if (gen != _gen) return;
    await map.addSource(sourceId, GeojsonSourceProperties(data: geoJson(stops, _opacity)));
    await map.addSymbolLayer(sourceId, layerId, layerProps, belowLayerId: below, enableInteraction: true);
    _drawn = true;
    _loadPhotos(map, gen).ignore();
  }

  Future<void> setOpacity(MapLibreMapController map, List<double> opacity) async {
    if (!_drawn || listEquals(opacity, _opacity)) return;
    _opacity = [...opacity];
    await map.setGeoJsonSource(sourceId, geoJson(_stops, _opacity));
  }

  void dispose() => _gen++;

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
        if (_stops[i].spot.hasThumb && !_png.containsKey(_stops[i].key(true))) i,
    ];
    final step = tuning.maxDownloads < 1 ? 1 : tuning.maxDownloads;
    for (var k = 0; k < todo.length; k += step) {
      final chunk = todo.sublist(k, k + step > todo.length ? todo.length : k + step);
      await Future.wait([
        for (final i in chunk)
          () async {
            try {
              final s = _stops[i];
              final thumb = await _images.thumb(s.spot);
              if (thumb == null || gen != _gen) return;
              final png = await _render(s, thumb);
              if (gen != _gen) return;
              await map.addImage(imageOf(i), png);
            } catch (_) {}
          }(),
      ]);
      if (gen != _gen) return;
    }
  }

  Future<Uint8List> _render(RouteStop s, Uint8List? thumb) async {
    final png = await painter.stop(thumb: thumb, category: s.spot.category, ring: s.ring, number: s.number, t: tuning);
    if (thumb != null) {
      _png.remove(s.key(true));
      _png[s.key(true)] = png;
      while (_png.length > _cacheMax) {
        _png.remove(_png.keys.first);
      }
    }
    return png;
  }
}
