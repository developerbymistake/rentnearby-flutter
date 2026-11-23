import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../design/design.dart';
import '../../../trip/map/trip_route_stops.dart';
import 'viewer_map_scene.dart';

class ViewerMapView {
  const ViewerMapView({required this.scene, required this.selected, required this.picked, required this.onTap});

  final ViewerMapScene scene;
  final int selected;
  final ViewerMapStop? picked;
  final ValueChanged<ViewerMapStop?> onTap;
}

/// One live map for every day: a day pick only changes opacities and the camera, never the map.
class ViewerRouteMap extends StatefulWidget {
  const ViewerRouteMap({super.key, required this.view, required this.padding, required this.onMap});

  final ViewerMapView view;
  final EdgeInsets Function() padding;
  final ValueChanged<MapLibreMapController?> onMap;

  static const double glowAlpha = 0.18;
  static const List<double> noRoadDots = [0, 2.5];

  static String sourceId(int day) => 'viewer-day-$day';

  static List<(String, LineLayerProperties)> lineLayers(ViewerMapDay d, double opacity) {
    final id = sourceId(d.day);
    final color = TripKit.hexOf(d.color);
    return [
      (
        '$id-glow',
        LineLayerProperties(lineColor: color, lineWidth: DS.s(12), lineBlur: DS.s(3), lineOpacity: opacity * glowAlpha, lineCap: 'round', lineJoin: 'round'),
      ),
      if (!d.dashed)
        (
          '$id-edge',
          LineLayerProperties(lineColor: TripKit.hexOf(DesignColors.surface), lineWidth: DS.s(11), lineOpacity: opacity, lineCap: 'round', lineJoin: 'round'),
        ),
      (
        '$id-line',
        LineLayerProperties(
          lineColor: color,
          lineWidth: DS.s(8),
          lineOpacity: opacity,
          lineCap: 'round',
          lineJoin: 'round',
          lineDasharray: d.dashed ? noRoadDots : null,
        ),
      ),
    ];
  }

  @override
  State<ViewerRouteMap> createState() => _ViewerRouteMapState();
}

class _ViewerRouteMapState extends State<ViewerRouteMap> {
  MapLibreMapController? _map;
  final _stops = TripRouteStops(tuning: ViewerMapScene.tuning);
  final _drawn = <String>[];
  final _sources = <String>[];
  Circle? _halo;
  bool _styled = false;
  Future<void> _queue = Future.value();

  ViewerMapView get _v => widget.view;

  @override
  void didUpdateWidget(ViewerRouteMap old) {
    super.didUpdateWidget(old);
    final o = old.view, n = widget.view;
    if (!identical(o.scene, n.scene)) {
      _run(_draw);
    } else if (o.selected != n.selected) {
      _run(_applySelection);
    }
    if (o.picked != n.picked || !identical(o.scene, n.scene)) _run(_drawHalo);
  }

  @override
  void dispose() {
    _stops.dispose();
    _map?.onFeatureTapped.remove(_onFeatureTapped);
    widget.onMap(null);
    super.dispose();
  }

  void _run(Future<void> Function() op) {
    _queue = _queue.then((_) async {
      if (!mounted || !_styled || _map == null) return;
      try {
        await op();
      } catch (_) {}
    });
  }

  LatLng get _start {
    final b = _v.scene.bounds(ViewerMapScene.all);
    if (b == null) return const LatLng(29.39, 79.45);
    return LatLng((b.southwest.latitude + b.northeast.latitude) / 2, (b.southwest.longitude + b.northeast.longitude) / 2);
  }

  Future<void> _clear(MapLibreMapController map) async {
    for (final id in _drawn) {
      await map.removeLayer(id);
    }
    for (final id in _sources) {
      await map.removeSource(id);
    }
    _drawn.clear();
    _sources.clear();
  }

  Future<void> _draw() async {
    final map = _map!;
    await _clear(map);
    final scene = _v.scene;
    final below = map.circleManager?.layerIds.first;
    for (final d in scene.days) {
      if (!d.hasLine) continue;
      final id = ViewerRouteMap.sourceId(d.day);
      await map.addGeoJsonSource(id, d.source);
      _sources.add(id);
      for (final (layer, props) in ViewerRouteMap.lineLayers(d, scene.lineOpacity(d.day, _v.selected))) {
        await map.addLineLayer(id, layer, props, belowLayerId: below, enableInteraction: false);
        _drawn.add(layer);
      }
    }
    await _stops.draw(map, [for (final s in scene.stops) s.route], scene.stopOpacities(_v.selected), below: below);
    await _fit(map);
  }

  Future<void> _applySelection() async {
    final map = _map!;
    final scene = _v.scene;
    for (final d in scene.days) {
      if (!d.hasLine) continue;
      for (final (layer, props) in ViewerRouteMap.lineLayers(d, scene.lineOpacity(d.day, _v.selected))) {
        if (_drawn.contains(layer)) await map.setLayerProperties(layer, props);
      }
    }
    await _stops.setOpacity(map, scene.stopOpacities(_v.selected));
    await _fit(map);
  }

  Future<void> _drawHalo() async {
    final map = _map!;
    final old = _halo;
    _halo = null;
    if (old != null) await map.removeCircle(old);
    final p = _v.picked;
    if (p == null) return;
    _halo = await map.addCircle(CircleOptions(
      geometry: LatLng(p.spot.latitude!, p.spot.longitude!),
      circleRadius: ViewerMapScene.tuning.photoDp / 2 + DS.s(7),
      circleOpacity: 0,
      circleStrokeColor: TripKit.hexOf(p.color),
      circleStrokeWidth: DS.s(3),
      circleStrokeOpacity: Alpha.v45,
    ));
  }

  Future<void> _fit(MapLibreMapController map) async {
    final b = _v.scene.bounds(_v.selected);
    if (b == null || !mounted) return;
    final pad = widget.padding();
    final size = MediaQuery.sizeOf(context);
    if (b.northeast.latitude - b.southwest.latitude < 0.0005 && b.northeast.longitude - b.southwest.longitude < 0.0005) {
      await map.animateCamera(CameraUpdate.newLatLngZoom(b.southwest, 14));
      return;
    }
    var top = pad.top, bottom = pad.bottom;
    final room = size.height - DS.s(120);
    if (top + bottom > room && room > 0) {
      final k = room / (top + bottom);
      top *= k;
      bottom *= k;
    }
    final across = pad.left + pad.right;
    final side = across > size.width / 2 ? size.width / 2 / across : 1.0;
    await map.animateCamera(CameraUpdate.newLatLngBounds(b, left: pad.left * side, top: top, right: pad.right * side, bottom: bottom));
  }

  void _onFeatureTapped(Point<double> point, LatLng at, String id, String layerId, Annotation? annotation) {
    if (annotation != null || layerId != TripRouteStops.layerId) return;
    final s = _stops.at(id);
    final stop = s == null ? null : _v.scene.stopAt(s.day, s.index);
    if (stop != null) _v.onTap(stop);
  }

  void _onStyleLoaded() {
    _styled = true;
    _run(_draw);
    _run(_drawHalo);
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: MapLibreMap(
          styleString: 'assets/map_style.json',
          initialCameraPosition: CameraPosition(target: _start, zoom: 12),
          compassEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          myLocationEnabled: false,
          trackCameraPosition: false,
          attributionButtonMargins: const Point(-200.0, 0.0),
          annotationOrder: const [AnnotationType.circle, AnnotationType.symbol],
          onMapClick: (_, _) => _v.onTap(null),
          onMapCreated: (c) {
            _map = c;
            c.onFeatureTapped.add(_onFeatureTapped);
            widget.onMap(c);
          },
          onStyleLoadedCallback: _onStyleLoaded,
        ),
      );
}
