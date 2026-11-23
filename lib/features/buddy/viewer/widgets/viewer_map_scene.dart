import 'dart:math';

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../design/design.dart';
import '../../../trip/map/discovery_api.dart';
import '../../../trip/map/trip_route_stops.dart';
import '../data/viewer_spot_photos.dart';
import '../models/viewer_models.dart';
import '../viewer_look.dart';
import '../viewer_rules.dart';
import '../viewer_strings.dart';

class ViewerMapStop {
  const ViewerMapStop({required this.day, required this.index, required this.spot, required this.color, this.cityKey, this.photoUrl});

  final int day;
  final int index;
  final ViewerSpot spot;
  final Color color;
  final int? cityKey;
  final String? photoUrl;

  int get number => index + 1;

  DiscoverySpot get disc => DiscoverySpot(
        id: spot.id,
        lat: spot.latitude!,
        lon: spot.longitude!,
        category: spot.category ?? '',
        rank: 0,
        name: spot.name,
        cityKey: cityKey,
        thumbUrl: photoUrl,
        visitMinutes: spot.visitMinutes > 0 ? spot.visitMinutes : null,
      );

  RouteStop get route => RouteStop(day: day, index: index, number: number, spot: disc, ring: color);

  String get line => ViewerStrings.stopLine(day, number, spot.visitMinutes > 0 ? ViewerRules.duration(spot.visitMinutes) : null);
}

class ViewerMapDay {
  const ViewerMapDay({required this.day, required this.color, required this.points, this.road});

  final int day;
  final Color color;
  final List<LatLng> points;
  final Map<String, dynamic>? road;

  bool get dashed => road == null;
  bool get hasLine => road != null || points.length > 1;

  Map<String, dynamic> get source => road ??
      {
        'type': 'FeatureCollection',
        'features': [
          if (points.length > 1)
            {
              'type': 'Feature',
              'properties': <String, dynamic>{},
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  for (final p in points) [p.longitude, p.latitude],
                ],
              },
            },
        ],
      };
}

class ViewerMapScene {
  const ViewerMapScene({required this.days, required this.stops});

  final List<ViewerMapDay> days;
  final List<ViewerMapStop> stops;

  static const int all = 0;
  static const double dimLine = 0.25;
  static const double dimStop = 0.45;

  static DiscTuning get tuning => DiscTuning(photoMax: 40, photoDp: DS.s(54));

  factory ViewerMapScene.of(List<ViewerDay> days, List<ViewerLeg> legs, {String? Function(String spotId) photoOf = ViewerSpotPhotos.urlFor}) {
    final cityOf = {for (final l in legs) l.index: l.cityKey};
    final outDays = <ViewerMapDay>[];
    final stops = <ViewerMapStop>[];
    for (final d in days) {
      final color = ViewerLook.routeColor(d.day);
      final placed = [for (final s in d.spots) if (s.latitude != null && s.longitude != null) s];
      if (placed.isEmpty) continue;
      for (var i = 0; i < placed.length; i++) {
        final s = placed[i];
        stops.add(ViewerMapStop(day: d.day, index: i, spot: s, color: color, cityKey: cityOf[d.leg], photoUrl: photoOf(s.id)));
      }
      outDays.add(ViewerMapDay(day: d.day, color: color, points: [for (final s in placed) LatLng(s.latitude!, s.longitude!)], road: roadOf(d.routeGeoJson)));
    }
    return ViewerMapScene(days: outDays, stops: stops);
  }

  static Map<String, dynamic>? roadOf(Object? geo) {
    if (geo is! Map) return null;
    final g = Map<String, dynamic>.from(geo);
    final type = g['type'];
    if (type == 'FeatureCollection') return _lines(g).isEmpty ? null : g;
    final Map<String, dynamic> feature = type == 'Feature' ? g : {'type': 'Feature', 'properties': <String, dynamic>{}, 'geometry': g};
    final out = {
      'type': 'FeatureCollection',
      'features': [feature],
    };
    return _lines(out).isEmpty ? null : out;
  }

  static List<List<num>> _lines(Map<String, dynamic> collection) {
    final out = <List<num>>[];
    final features = collection['features'];
    if (features is! List) return out;
    for (final f in features) {
      final geometry = f is Map ? f['geometry'] : null;
      if (geometry is! Map) continue;
      final coords = geometry['coordinates'];
      final lines = switch (geometry['type']) {
        'LineString' => [coords],
        'MultiLineString' => coords is List ? coords : const [],
        _ => const [],
      };
      for (final line in lines) {
        if (line is! List || line.length < 2) continue;
        for (final p in line) {
          if (p is List && p.length >= 2 && p[0] is num && p[1] is num) out.add([p[0] as num, p[1] as num]);
        }
      }
    }
    return out;
  }

  bool shows(int day, int selected) => selected == all || selected == day;

  double lineOpacity(int day, int selected) => shows(day, selected) ? 1 : dimLine;

  double stopOpacity(int day, int selected) => shows(day, selected) ? 1 : dimStop;

  List<double> stopOpacities(int selected) => [for (final s in stops) stopOpacity(s.day, selected)];

  bool dashedShown(int selected) => days.any((d) => d.dashed && d.hasLine && shows(d.day, selected));

  ViewerMapStop? stopAt(int day, int index) {
    for (final s in stops) {
      if (s.day == day && s.index == index) return s;
    }
    return null;
  }

  List<LatLng> focus(int selected) => [
        for (final d in days)
          if (shows(d.day, selected)) ...[
            ...d.points,
            if (d.road != null)
              for (final p in _lines(d.road!)) LatLng(p[1].toDouble(), p[0].toDouble()),
          ],
      ];

  LatLngBounds? bounds(int selected) {
    final p = focus(selected);
    if (p.isEmpty) return null;
    return LatLngBounds(
      southwest: LatLng(p.map((e) => e.latitude).reduce(min), p.map((e) => e.longitude).reduce(min)),
      northeast: LatLng(p.map((e) => e.latitude).reduce(max), p.map((e) => e.longitude).reduce(max)),
    );
  }
}
