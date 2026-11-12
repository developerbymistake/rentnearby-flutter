import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
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

  Color _color(int legIndex) {
    final c = JourneyRail.colorFor(legIndex);
    final sel = selectedLeg;
    return sel == null || sel == legIndex ? c : c.withValues(alpha: Alpha.scrim);
  }

  @override
  Widget build(BuildContext context) {
    final legs = plan.legs;
    if (legs.isEmpty) return const SizedBox.shrink();
    final rows = <Widget>[
      RailRow(
        marker: RailMarker.start,
        below: _color(legs.first.index),
        dashed: !legs.first.hasRoadLine,
        child: _place(legs.first.from.name, TaxiWaysStrings.youStart),
      ),
    ];
    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final c = _color(leg.index);
      rows.add(RailRow(
        above: c,
        below: c,
        dashed: !leg.hasRoadLine,
        child: _stretch(leg, c),
      ));
      if (i < legs.length - 1) {
        final next = legs[i + 1];
        rows.add(RailRow(
          marker: RailMarker.change,
          above: c,
          below: _color(next.index),
          dashed: !next.hasRoadLine,
          child: _place(
            leg.to.name,
            TaxiWaysStrings.changeCar,
            note: next.meetingPlace != null && next.meetingPlace != leg.to.name
                ? '${TaxiWaysStrings.meetNext} · ${next.meetingPlace}'
                : TaxiWaysStrings.meetNext,
            change: true,
          ),
        ));
      }
    }
    rows.add(RailRow(
      marker: RailMarker.end,
      above: _color(legs.last.index),
      dashed: !legs.last.hasRoadLine,
      child: _place(legs.last.to.name, TaxiWaysStrings.youArrive),
    ));
    return TemplateStagger(children: rows);
  }

  Widget _place(String name, String caption, {String? note, bool change = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FitnessAppTheme.title.copyWith(fontSize: 15),
          ),
          Text(
            caption,
            style: FitnessAppTheme.caption.copyWith(
              fontSize: 11.5,
              fontWeight: change ? FontWeight.w700 : FontWeight.w400,
              color: change ? TripLook.warningText : DesignColors.textSecondary,
            ),
          ),
          if (note != null)
            Text(
              note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: FitnessAppTheme.caption.copyWith(fontSize: 11, color: DesignColors.textGrey),
            ),
        ]),
      );

  Widget _stretch(WayLeg leg, Color color) {
    final d = chosen[leg.index] ?? leg.firstDriver;
    final km = leg.distanceKm ?? d?.distanceKm;
    final line = [
      TaxiWaysStrings.subtitle(leg.from.name, leg.to.name),
      if (km != null && km > 0) TaxiWaysStrings.aboutKm(km),
    ].join(' · ');
    final selected = selectedLeg == leg.index;
    final geometry = leg.geometry;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () => onSelectLeg(leg.index),
        borderRadius: TripLook.softRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: Alpha.hairline) : DesignColors.surface,
            borderRadius: TripLook.softRadius,
            boxShadow: selected ? TripLook.shadowFor(color) : TripLook.card().boxShadow,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (d != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: Alpha.full), color.withValues(alpha: Alpha.strong)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Text(d.initial, style: FitnessAppTheme.title.copyWith(fontSize: 13, color: DesignColors.surface)),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (d != null)
                    Text(
                      d.driverName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FitnessAppTheme.title.copyWith(fontSize: 13.5),
                    ),
                  Text(
                    line,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FitnessAppTheme.caption.copyWith(fontSize: 11.5),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              Text(
                BrowseItem.inr(chosen[leg.index]?.groupFare(people) ?? leg.listedFare),
                style: FitnessAppTheme.title.copyWith(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ]),
            if (geometry != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                width: double.infinity,
                child: CustomPaint(painter: _LineSketchPainter(points: geometry, color: color.withValues(alpha: Alpha.full))),
              ),
            ],
            if (leg.passes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                TaxiWaysStrings.passes(leg.passes),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: FitnessAppTheme.caption.copyWith(fontSize: 11.5, fontWeight: FontWeight.w600, color: DesignColors.textGrey),
              ),
            ],
            if (!leg.hasRoadLine) ...[
              const SizedBox(height: 6),
              Text(
                TaxiWaysStrings.noRoadLine,
                style: FitnessAppTheme.caption.copyWith(fontSize: 11, fontStyle: FontStyle.italic, color: DesignColors.textMuted),
              ),
            ],
          ]),
        ),
      ),
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
