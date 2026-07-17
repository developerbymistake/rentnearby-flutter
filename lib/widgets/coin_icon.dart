import 'package:flutter/material.dart';

/// The app's one coin glyph — a hand-drawn gold coin (radial gradient circle,
/// dashed inner ring, bold "C" center), not a Material money icon. Every
/// screen that shows a coin amount uses this at whatever size it needs,
/// mirroring the original coinSVG() design used throughout the approved
/// coin-economy mockup — never Icons.monetization_on_rounded (which reads as
/// a literal dollar sign) and never a plain "$"/"₹" glyph for coin counts.
class CoinIcon extends StatelessWidget {
  final double size;

  const CoinIcon({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CoinPainter()),
    );
  }
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      const Color(0x59B45309),
      1.2,
      false,
    );

    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.4), // lit from upper-left, matches cx:35% cy:30%
      radius: 0.85,
      colors: const [Color(0xFFFDE68A), Color(0xFFF59E0B), Color(0xFFB45309)],
      stops: const [0.0, 0.55, 1.0],
    );
    final fillPaint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, fillPaint);

    final strokePaint = Paint()
      ..color = const Color(0xFF92400E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025;
    canvas.drawCircle(center, radius - strokePaint.strokeWidth / 2, strokePaint);

    // Dashed inner ring
    final ringRadius = radius * 0.73;
    final dashPaint = Paint()
      ..color = const Color(0x8CFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.028;
    // Matches the mockup's SVG stroke-dasharray (2.2 2.6 on an r=13.5 circle,
    // ~4.245 degrees per px of arc length) — same dash:gap ratio, same
    // density, not just the same proportion.
    const dashDeg = 9.3;
    const gapDeg = 11.0;
    var startDeg = 0.0;
    while (startDeg < 360) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringRadius),
        startDeg * 3.1415926535 / 180,
        dashDeg * 3.1415926535 / 180,
        false,
        dashPaint,
      );
      startDeg += dashDeg + gapDeg;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'C',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          fontSize: size.width * 0.42,
          color: const Color(0xFF7C2D12),
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CoinPainter oldDelegate) => false;
}
