import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:bakhli/features/trip/map/trip_route_stops.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show GeojsonSourceProperties, MapLibreMapController, SourceProperties, SymbolLayerProperties;

/// Records what the stop layer sends to the map: every addImage call, the image each name holds now, and the source.
class RouteStopsFakeMap extends Fake implements MapLibreMapController {
  final images = <String>[];
  final held = <String, Uint8List>{};
  Map<String, dynamic>? source;
  int sourceSets = 0;

  @override
  Future<void> addImage(String name, Uint8List bytes, [bool sdf = false]) async {
    images.add(name);
    held[name] = bytes;
  }

  @override
  Future<void> addSource(String sourceid, SourceProperties properties) async {
    final data = properties is GeojsonSourceProperties ? properties.data : null;
    source = data is Map<String, dynamic> ? data : null;
  }

  @override
  Future<void> setGeoJsonSource(String sourceId, Map<String, dynamic> geojson) async {
    source = geojson;
    sourceSets++;
  }

  @override
  Future<void> addSymbolLayer(
    String sourceId,
    String layerId,
    SymbolLayerProperties properties, {
    String? belowLayerId,
    String? sourceLayer,
    double? minzoom,
    double? maxzoom,
    dynamic filter,
    bool enableInteraction = true,
  }) async {}

  @override
  Future<void> removeLayer(String layerId) async {}

  @override
  Future<void> removeSource(String sourceId) async => source = null;

  List<Map<String, dynamic>> get featureProps => [
        for (final f in (source?['features'] as List? ?? const []))
          Map<String, dynamic>.from((f as Map)['properties'] as Map),
      ];

  Set<String> get dotImages => {for (final k in held.keys) if (k.startsWith(TripRouteStops.dotPrefix)) k};

  /// Stop slots that hold a real photo stop now (a cleared slot holds a 1 px image), with their texture bytes.
  Future<Map<String, int>> fullTextures() async {
    final out = <String, int>{};
    for (final e in held.entries) {
      if (!e.key.startsWith(TripRouteStops.imagePrefix) || e.key.startsWith(TripRouteStops.dotPrefix)) continue;
      final codec = await ui.instantiateImageCodec(e.value);
      final img = (await codec.getNextFrame()).image;
      if (img.width > 1) out[e.key] = img.width * img.height * 4;
      img.dispose();
      codec.dispose();
    }
    return out;
  }
}
