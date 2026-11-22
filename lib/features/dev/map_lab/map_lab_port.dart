import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'map_lab_spikes.dart';

class MapLibreLabPort implements LabMapPort {
  final MapLibreMapController map;
  final Size Function() viewportOf;
  final double Function() ratioOf;
  final List<String> _layers = [];
  final List<String> _sources = [];

  MapLibreLabPort(this.map, this.viewportOf, this.ratioOf);

  @override
  Size get viewport => viewportOf();

  @override
  double get devicePixelRatio => ratioOf();

  @override
  Future<void> reset() async {
    await clear();
    await map.moveCamera(CameraUpdate.newCameraPosition(
      const CameraPosition(target: LatLng(LabCentre.lat, LabCentre.lon), zoom: LabCentre.zoom),
    ));
    await settle(const Duration(milliseconds: 700));
  }

  @override
  Future<void> addGeoJson(String sourceId, Map<String, dynamic> data) async {
    await map.addGeoJsonSource(sourceId, data);
    _sources.add(sourceId);
  }

  @override
  Future<void> addFileSource(String sourceId, String url) async {
    await map.addSource(sourceId, GeojsonSourceProperties(data: url));
    _sources.add(sourceId);
  }

  @override
  Future<void> addCircles(String sourceId, String layerId, {required double radius, bool interactive = true}) async {
    await map.addCircleLayer(
      sourceId,
      layerId,
      CircleLayerProperties(
        circleRadius: radius,
        circleColor: '#E53935',
        circleStrokeWidth: 1,
        circleStrokeColor: '#FFFFFF',
      ),
      enableInteraction: interactive,
    );
    _layers.add(layerId);
  }

  @override
  Future<void> addSymbols(
    String sourceId,
    String layerId, {
    required Object iconImage,
    Object? sortKey,
    bool overlap = false,
  }) async {
    await map.addSymbolLayer(
      sourceId,
      layerId,
      SymbolLayerProperties(
        iconImage: iconImage,
        iconAllowOverlap: overlap,
        iconIgnorePlacement: false,
        symbolSortKey: sortKey,
      ),
    );
    _layers.add(layerId);
  }

  @override
  Future<void> addImage(String name, Uint8List bytes) => map.addImage(name, bytes);

  @override
  Future<List<Object?>> queryPoint(double x, double y, List<String> layerIds) async =>
      List<Object?>.from(await map.queryRenderedFeatures(Point<double>(x, y), layerIds, null));

  @override
  Future<List<Object?>> queryRect(Rect rect, List<String> layerIds) async =>
      List<Object?>.from(await map.queryRenderedFeaturesInRect(rect, layerIds, null));

  @override
  Future<({double x, double y})> toScreen(double lat, double lon) async {
    final p = await map.toScreenLocation(LatLng(lat, lon));
    return (x: p.x.toDouble(), y: p.y.toDouble());
  }

  @override
  Future<void> panTo(double lat, double lon, {double? zoom, Duration duration = const Duration(milliseconds: 800)}) async {
    await map.animateCamera(
      zoom == null ? CameraUpdate.newLatLng(LatLng(lat, lon)) : CameraUpdate.newLatLngZoom(LatLng(lat, lon), zoom),
      duration: duration,
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> settle([Duration wait = const Duration(milliseconds: 1500)]) => Future<void>.delayed(wait);

  @override
  Future<void> clear() async {
    for (final l in _layers.reversed) {
      try {
        await map.removeLayer(l);
      } catch (_) {}
    }
    for (final s in _sources.reversed) {
      try {
        await map.removeSource(s);
      } catch (_) {}
    }
    _layers.clear();
    _sources.clear();
  }
}
