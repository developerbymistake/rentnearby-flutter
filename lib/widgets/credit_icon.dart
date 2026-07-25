import 'package:flutter/material.dart';
import '../config/app_colors.dart';

/// The app's one credit glyph — a squircle "badge" (rounded-square shape,
/// diagonal navy-to-blue gradient matching AppColors.primaryGradient, bold
/// "C" center), deliberately not a literal coin: no circle silhouette, no
/// gold/bronze tones. Every screen that shows a credit amount uses this at
/// whatever size it needs — never Icons.monetization_on_rounded (which reads
/// as a literal dollar sign) and never a plain "$"/"₹" glyph for credit counts.
class CreditIcon extends StatelessWidget {
  final double size;

  const CreditIcon({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CreditPainter()),
    );
  }
}

class _CreditPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    // Squircle radius proportional to size, same rounding language as the
    // rest of the app's cards/chips rather than a near-circle superellipse.
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.32));

    canvas.drawShadow(Path()..addRRect(rrect), const Color(0x591E3A8A), 1.2, false);

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [AppColors.primary, AppColors.primaryLight],
    );
    final fillPaint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRRect(rrect, fillPaint);

    final strokePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025;
    canvas.drawRRect(rrect.deflate(strokePaint.strokeWidth / 2), strokePaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'C',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          fontSize: size.width * 0.44,
          color: Colors.white,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final center = Offset(size.width / 2, size.height / 2);
    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _CreditPainter oldDelegate) => false;
}
