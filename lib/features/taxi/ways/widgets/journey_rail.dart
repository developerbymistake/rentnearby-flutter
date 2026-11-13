import 'package:flutter/material.dart';
import 'package:bakhli/design/design.dart';
import 'package:bakhli/design/extra/ext_journeys.dart';
import 'package:bakhli/design/extra/trip_plan_look.dart';
import '../../../trip/utils/trip_format.dart';
import '../models/taxi_ways_models.dart';
import '../taxi_ways_strings.dart';
import '../trip_strings_a6.dart';
import 'journey_driver_card.dart';

enum RailMarker { start, end, change, none }

class JourneyRail extends StatelessWidget {
  static const List<Color> legColors = WaysTokens.legColors;

  static Color colorFor(int legIndex) => legColors[(legIndex - 1).abs() % legColors.length];

  final WayPlan plan;
  final Map<int, WayDriver> chosen;
  final DateTime date;
  final void Function(WayLeg leg)? onChangeDriver;

  const JourneyRail({
    super.key,
    required this.plan,
    required this.chosen,
    required this.date,
    this.onChangeDriver,
  });

  static ListingTone toneFor(int legIndex) => JourneyInk.legTone(legIndex);

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    final legs = plan.legs;
    if (legs.isEmpty) return const SizedBox.shrink();
    items.add(JourneyStop3D(
      top: 16,
      title: legs.first.from.name,
      subtitle: '${TaxiWaysStrings.youStart} · ${TripFormat.shortDate(date)}',
    ));
    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final t = toneFor(leg.index);
      final d = chosen[leg.index] ?? leg.firstDriver;
      items.add(JourneyLink3D(color: t.g1));
      if (d != null) {
        items.add(JourneyDriverCard(
          driver: d,
          tone: t,
          tag: legs.length > 1 ? TaxiWaysStrings.carOf(i + 1, legs.length) : null,
          route: TaxiWaysStrings.subtitle(leg.from.name, leg.to.name),
          otherCount: leg.otherCount,
          seatsNote: TripStringsA6.legSeats(leg),
          onChange: onChangeDriver == null ? null : () => onChangeDriver!(leg),
          linkAbove: t.g1,
        ));
        items.add(Padding(padding: const EdgeInsets.only(top: 2), child: JourneyLink3D(color: t.g1)));
      }
      if (i < legs.length - 1) {
        final next = legs[i + 1];
        final meet = next.meetingPlace;
        items.add(JourneyStop3D(
          top: 0,
          change: true,
          title: leg.to.name,
          tag: TaxiWaysStrings.changeCarHere,
          subtitle: meet != null && meet != leg.to.name ? '${TaxiWaysStrings.meetNext} · $meet' : TaxiWaysStrings.meetNext,
        ));
      }
    }
    items.add(JourneyStop3D(top: 0, art: ListingArt.flag, title: legs.last.to.name, subtitle: TaxiWaysStrings.youArrive));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items);
  }
}

class RailRow extends StatelessWidget {
  final RailMarker marker;
  final Color? above;
  final Color? below;
  final bool dashed;
  final Widget child;

  const RailRow({
    super.key,
    required this.child,
    this.marker = RailMarker.none,
    this.above,
    this.below,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 30,
          child: CustomPaint(painter: _GutterPainter(marker: marker, above: above, below: below, dashed: dashed)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
        ),
      ]),
    );
  }
}

class _GutterPainter extends CustomPainter {
  final RailMarker marker;
  final Color? above;
  final Color? below;
  final bool dashed;

  _GutterPainter({required this.marker, this.above, this.below, this.dashed = false});

  static const double _markerY = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final hasMarker = marker != RailMarker.none;
    final midY = hasMarker ? _markerY : size.height / 2;
    final line = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    if (above != null) {
      line.color = above!;
      _line(canvas, Offset(x, 0), Offset(x, midY), line);
    }
    if (below != null) {
      line.color = below!;
      _line(canvas, Offset(x, midY), Offset(x, size.height), line);
    }
    if (!hasMarker) return;
    final fill = Paint()..style = PaintingStyle.fill;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    switch (marker) {
      case RailMarker.change:
        fill.color = TripLook.warningSurface;
        ring.color = WaysTokens.changeAccent;
        canvas.drawCircle(Offset(x, midY), 11, Paint()..color = DesignColors.surface);
        canvas.drawCircle(Offset(x, midY), 11, fill);
        canvas.drawCircle(Offset(x, midY), 11, ring);
      case RailMarker.start:
        fill.color = DesignColors.surface;
        ring.color = below ?? DesignColors.primary;
        canvas.drawCircle(Offset(x, midY), 8, fill);
        canvas.drawCircle(Offset(x, midY), 8, ring);
      case RailMarker.end:
        fill.color = above ?? DesignColors.primary;
        canvas.drawCircle(Offset(x, midY), 9, fill);
        fill.color = DesignColors.surface;
        canvas.drawCircle(Offset(x, midY), 3.5, fill);
      case RailMarker.none:
        break;
    }
  }

  void _line(Canvas canvas, Offset a, Offset b, Paint p) {
    if (!dashed) {
      canvas.drawLine(a, b, p);
      return;
    }
    const dash = 6.0;
    const gap = 5.0;
    var y = a.dy;
    while (y < b.dy) {
      final end = (y + dash).clamp(a.dy, b.dy);
      canvas.drawLine(Offset(a.dx, y), Offset(a.dx, end), p);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _GutterPainter old) =>
      old.marker != marker || old.above != above || old.below != below || old.dashed != dashed;
}
