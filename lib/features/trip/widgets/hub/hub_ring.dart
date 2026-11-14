import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'hub_tokens.dart';

class HubRing extends StatelessWidget {
  const HubRing({
    super.key,
    required this.percent,
    this.size = 46,
    this.thickness = 5,
    this.arc = HubTokens.accent,
    this.track = HubTokens.trackRing,
    this.center,
  });

  final int percent;
  final double size;
  final double thickness;
  final Color arc;
  final Color track;
  final Widget? center;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(percent.clamp(0, 100) / 100, thickness, arc, track),
          child: center == null ? null : Center(child: center),
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.thickness, this.arc, this.track);

  final double fraction;
  final double thickness;
  final Color arc;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(thickness / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    if (fraction <= 0) return;
    base.color = arc;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * fraction, false, base);
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.fraction != fraction || o.thickness != thickness || o.arc != arc || o.track != track;
}
