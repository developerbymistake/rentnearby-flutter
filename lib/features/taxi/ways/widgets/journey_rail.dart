import 'package:flutter/material.dart';
import '../../../../config/app_colors.dart';
import '../../../trip/trip_colors.dart';
import '../../../trip/utils/trip_format.dart';
import '../../taxi_option_sets.dart';
import '../models/taxi_ways_models.dart';
import '../taxi_ways_strings.dart';
import '../trip_strings_a6.dart';
import 'journey_change_stop.dart';
import 'journey_driver_card.dart';

enum RailMarker { start, end, change, none }

class JourneyRail extends StatelessWidget {
  static const List<Color> legColors = [TaxiColors.accent, TripStatusColors.booked, TripStatusColors.advance];

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

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    final legs = plan.legs;
    if (legs.isEmpty) return const SizedBox.shrink();
    items.add(RailRow(
      marker: RailMarker.start,
      below: colorFor(legs.first.index),
      child: _placeText(legs.first.from.name, '${TaxiWaysStrings.youStart} · ${TripFormat.shortDate(date)}'),
    ));
    for (var i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final c = colorFor(leg.index);
      final d = chosen[leg.index] ?? leg.firstDriver;
      if (d != null) {
        items.add(RailRow(
          above: c,
          below: c,
          child: JourneyDriverCard(
            driver: d,
            color: c,
            otherCount: leg.otherCount,
            seatsNote: TripStringsA6.legSeats(leg),
            onChange: onChangeDriver == null ? null : () => onChangeDriver!(leg),
          ),
        ));
      }
      if (i < legs.length - 1) {
        items.add(RailRow(
          marker: RailMarker.change,
          above: c,
          below: colorFor(legs[i + 1].index),
          child: JourneyChangeStop(placeName: leg.to.name, meetingPlace: legs[i + 1].meetingPlace),
        ));
      }
    }
    items.add(RailRow(
      marker: RailMarker.end,
      above: colorFor(legs.last.index),
      child: _placeText(legs.last.to.name, TaxiWaysStrings.youArrive),
    ));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items);
  }

  Widget _placeText(String name, String caption) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
          ),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textLight),
          ),
        ]),
      );
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
        fill.color = AppColors.warningSurface;
        ring.color = AppColors.warning;
        canvas.drawCircle(Offset(x, midY), 11, fill);
        canvas.drawCircle(Offset(x, midY), 11, ring);
      case RailMarker.start:
        fill.color = Colors.white;
        ring.color = below ?? TaxiColors.accentDark;
        canvas.drawCircle(Offset(x, midY), 8, fill);
        canvas.drawCircle(Offset(x, midY), 8, ring);
      case RailMarker.end:
        fill.color = above ?? TaxiColors.accentDark;
        canvas.drawCircle(Offset(x, midY), 9, fill);
        fill.color = Colors.white;
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
