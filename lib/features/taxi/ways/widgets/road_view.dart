import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
import '../../../../models/browse_item.dart';
import '../models/taxi_ways_models.dart';
import '../taxi_ways_strings.dart';
import 'journey_rail.dart';

class RoadView extends StatelessWidget {
  final WayPlan plan;
  final Map<int, WayDriver> chosen;
  final int? selectedLeg;
  final int people;
  final ValueChanged<int> onSelectLeg;

  const RoadView({
    super.key,
    required this.plan,
    required this.chosen,
    required this.onSelectLeg,
    this.people = 1,
    this.selectedLeg,
  });

  Color _line(int legIndex) => JourneyRail.toneFor(legIndex).g1;

  bool _faded(int legIndex) => selectedLeg != null && selectedLeg != legIndex;

  @override
  Widget build(BuildContext context) {
    final legs = plan.legs;
    if (legs.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[
      JourneyRoadRow(
        mark: RoadMark.start,
        below: _line(legs.first.index),
        dashedBelow: !legs.first.hasRoadLine,
        child: JourneyRoadPlace(title: legs.first.from.name, caption: TaxiWaysStrings.youStart),
      ),
    ];
    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final c = _line(leg.index);
      rows.add(JourneyRoadRow(
        above: c,
        below: c,
        dashedAbove: !leg.hasRoadLine,
        dashedBelow: !leg.hasRoadLine,
        faded: _faded(leg.index),
        child: _stretch(leg),
      ));
      if (i < legs.length - 1) {
        final next = legs[i + 1];
        rows.add(JourneyRoadRow(
          mark: RoadMark.change,
          above: c,
          below: _line(next.index),
          dashedAbove: !leg.hasRoadLine,
          dashedBelow: !next.hasRoadLine,
          child: JourneyRoadPlace(
            title: leg.to.name,
            tag: TaxiWaysStrings.changeCar,
            note: next.meetingPlace != null && next.meetingPlace != leg.to.name
                ? '${TaxiWaysStrings.meetNext} · ${next.meetingPlace}'
                : TaxiWaysStrings.meetNext,
          ),
        ));
      }
    }
    rows.add(JourneyRoadRow(
      mark: RoadMark.end,
      above: _line(legs.last.index),
      dashedAbove: !legs.last.hasRoadLine,
      child: JourneyRoadPlace(title: legs.last.to.name, caption: TaxiWaysStrings.youArrive),
    ));
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
    );
  }

  Widget _stretch(WayLeg leg) {
    final d = chosen[leg.index] ?? leg.firstDriver;
    final km = leg.distanceKm ?? d?.distanceKm;
    final first = [
      if (km != null && km > 0) TaxiWaysStrings.aboutKm(km),
      ?d?.driverName,
    ].join(' · ');
    final geometry = leg.geometry;
    return JourneyRoadStretch(
      tone: JourneyRail.toneFor(leg.index),
      art: JourneyArt.forVehicle(d?.vehicleTypeName, d?.seats),
      title: TaxiWaysStrings.subtitle(leg.from.name, leg.to.name),
      lines: [
        if (first.isNotEmpty) first,
        if (leg.passes.isNotEmpty) TaxiWaysStrings.passes(leg.passes),
        BrowseItem.inr(d?.groupFare(people) ?? leg.listedFare),
        if (!leg.hasRoadLine) TaxiWaysStrings.noRoadLine,
      ],
      sketch: geometry == null
          ? null
          : SizedBox(height: 40, width: double.infinity, child: CustomPaint(painter: _LineSketchPainter(points: geometry, color: DesignColors.textInverse))),
      selected: selectedLeg == leg.index,
      onTap: () => onSelectLeg(leg.index),
    );
  }
}

class _LineSketchPainter extends CustomPainter {
  final List<LatLngPair> points;
  final Color color;

  _LineSketchPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    var minLat = points.first.lat, maxLat = points.first.lat;
    var minLng = points.first.lng, maxLng = points.first.lng;
    for (final p in points) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLng = math.min(minLng, p.lng);
      maxLng = math.max(maxLng, p.lng);
    }
    final kx = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final w = math.max((maxLng - minLng) * kx, 1e-6);
    final h = math.max(maxLat - minLat, 1e-6);
    const pad = 6.0;
    final scale = math.min((size.width - 2 * pad) / w, (size.height - 2 * pad) / h);
    final ox = (size.width - w * scale) / 2;
    final oy = (size.height - h * scale) / 2;
    Offset at(LatLngPair p) => Offset(ox + (p.lng - minLng) * kx * scale, oy + (maxLat - p.lat) * scale);
    final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (final p in points.skip(1)) {
      final o = at(p);
      path.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final dot = Paint()..color = color;
    canvas.drawCircle(at(points.first), 3.5, dot);
    canvas.drawCircle(at(points.last), 3.5, dot);
  }

  @override
  bool shouldRepaint(covariant _LineSketchPainter old) => old.points != points || old.color != color;
}
