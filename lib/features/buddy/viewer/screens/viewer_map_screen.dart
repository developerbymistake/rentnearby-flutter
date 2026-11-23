import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../design/design.dart';
import '../../../trip/widgets/trip_plan_header.dart';
import '../../shared/buddy_look.dart';
import '../../shared/widgets/view_only_chip.dart';
import '../../shared/widgets/segment_tabs.dart';
import '../controllers/viewer_trip_controller.dart';
import '../models/viewer_models.dart';
import '../viewer_look.dart';
import '../viewer_strings.dart';

typedef ViewerMapBuilder = Widget Function(BuildContext context, List<ViewerDay> days);

class ViewerMapScreen extends StatefulWidget {
  const ViewerMapScreen({super.key, required this.tripId, this.day, this.mapBuilder});

  final String tripId;
  final int? day;
  final ViewerMapBuilder? mapBuilder;

  @override
  State<ViewerMapScreen> createState() => _ViewerMapScreenState();
}

class _ViewerMapScreenState extends State<ViewerMapScreen> {
  late final ViewerTripController _c;
  bool _own = false;
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    final existing = ViewerTripController.maybeOf(widget.tripId);
    if (existing != null) {
      _c = existing;
    } else {
      _own = true;
      _c = Get.put(ViewerTripController(widget.tripId), tag: widget.tripId);
    }
    _selected = widget.day ?? 0;
  }

  @override
  void dispose() {
    if (_own && identical(ViewerTripController.maybeOf(widget.tripId), _c)) Get.delete<ViewerTripController>(tag: widget.tripId, force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final t = _c.trip.value;
        final days = [for (final d in t?.days ?? const <ViewerDay>[]) if (d.spots.any((s) => s.latitude != null && s.longitude != null)) d];
        final shown = _selected == 0 ? days : [for (final d in days) if (d.day == _selected) d];
        final labels = [ViewerStrings.allDays, for (final d in days) ViewerStrings.dayChip(d.day)];
        final index = _selected == 0 ? 0 : 1 + days.indexWhere((d) => d.day == _selected);
        return Scaffold(
          backgroundColor: DesignColors.scaffold,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TripFlowHeader(title: t?.title ?? ViewerStrings.map, subtitle: ViewerStrings.map, onBack: Get.back, trailing: const [ViewOnlyChip()]),
              if (days.length > 1)
                SegmentTabs(
                  labels: labels,
                  selected: index < 0 ? 0 : index,
                  tone: BuddyLook.indigo,
                  margin: DS.insets(l: 18, t: 12, r: 18),
                  onTap: (i) => setState(() => _selected = i == 0 ? 0 : days[i - 1].day),
                ),
              Expanded(
                child: days.isEmpty
                    ? Center(
                        child: Padding(
                          padding: DS.all(24),
                          child: Text(ViewerStrings.noRouteYet, textAlign: TextAlign.center, style: Ink3D.text(14, FontWeight.w600, ViewerLook.sub, letterSpacing: 0)),
                        ),
                      )
                    : Padding(
                        padding: DS.all(12),
                        child: ClipRRect(
                          borderRadius: DS.circular(24),
                          child: widget.mapBuilder?.call(context, shown) ?? _ViewerMap(key: ValueKey('viewer_map_$_selected'), days: shown),
                        ),
                      ),
              ),
            ],
          ),
        );
      });
}

class _ViewerMap extends StatefulWidget {
  const _ViewerMap({super.key, required this.days});

  final List<ViewerDay> days;

  @override
  State<_ViewerMap> createState() => _ViewerMapState();
}

class _ViewerMapState extends State<_ViewerMap> {
  MapLibreMapController? _map;

  static String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  Iterable<LatLng> get _points sync* {
    for (final d in widget.days) {
      for (final s in d.spots) {
        if (s.latitude != null && s.longitude != null) yield LatLng(s.latitude!, s.longitude!);
      }
    }
  }

  LatLng get _center {
    final p = _points.toList();
    if (p.isEmpty) return const LatLng(29.39, 79.45);
    return LatLng(p.map((e) => e.latitude).reduce((a, b) => a + b) / p.length, p.map((e) => e.longitude).reduce((a, b) => a + b) / p.length);
  }

  // No road line from the server (OSRM down or past the day cap): the straight line is drawn dashed, not as a road.
  static const List<double> _noRoadDash = [2, 2];

  Future<void> _draw() async {
    final map = _map;
    if (map == null) return;
    final circles = <CircleOptions>[];
    final symbols = <SymbolOptions>[];
    for (final d in widget.days) {
      final color = _hex(ViewerLook.dayColors[(d.day - 1) % ViewerLook.dayColors.length]);
      final pts = [for (final s in d.spots) if (s.latitude != null && s.longitude != null) LatLng(s.latitude!, s.longitude!)];
      final geo = d.routeGeoJson;
      if (geo is Map<String, dynamic>) {
        await map.addGeoJsonSource('viewer-day-${d.day}', geo);
      } else if (pts.length > 1) {
        await map.addGeoJsonSource('viewer-day-${d.day}', {
          'type': 'FeatureCollection',
          'features': [
            {
              'type': 'Feature',
              'properties': <String, Object>{},
              'geometry': {
                'type': 'LineString',
                'coordinates': [for (final p in pts) [p.longitude, p.latitude]],
              },
            },
          ],
        });
      }
      if (geo is Map<String, dynamic> || pts.length > 1) {
        await map.addLineLayer('viewer-day-${d.day}', 'viewer-line-${d.day}', LineLayerProperties(lineColor: color, lineWidth: DS.s(4), lineOpacity: Alpha.v80, lineDasharray: geo is Map<String, dynamic> ? null : _noRoadDash));
      }
      for (var i = 0; i < pts.length; i++) {
        circles.add(CircleOptions(geometry: pts[i], circleRadius: DS.s(14), circleColor: color, circleStrokeColor: _hex(DesignColors.surface), circleStrokeWidth: DS.s(2)));
        symbols.add(SymbolOptions(geometry: pts[i], textField: '${i + 1}', fontNames: const ['Noto Sans Medium'], textSize: DS.f(14), textColor: _hex(DesignColors.surface)));
      }
    }
    if (circles.isNotEmpty) {
      await map.addCircles(circles);
      await map.addSymbols(symbols);
    }
    final p = _points.toList();
    if (p.length > 1) {
      final south = p.map((e) => e.latitude).reduce(min);
      final north = p.map((e) => e.latitude).reduce(max);
      final west = p.map((e) => e.longitude).reduce(min);
      final east = p.map((e) => e.longitude).reduce(max);
      await map.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east)), left: 48, top: 48, right: 48, bottom: 48));
    }
  }

  @override
  Widget build(BuildContext context) => MapLibreMap(
        styleString: 'assets/map_style.json',
        initialCameraPosition: CameraPosition(target: _center, zoom: 12),
        compassEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        myLocationEnabled: false,
        attributionButtonMargins: const Point(-200.0, 0.0),
        annotationOrder: const [AnnotationType.circle, AnnotationType.symbol],
        onMapCreated: (c) => _map = c,
        onStyleLoadedCallback: _draw,
      );
}
