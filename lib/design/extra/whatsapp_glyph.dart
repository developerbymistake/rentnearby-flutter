import 'package:flutter/material.dart';
import '../tokens/design_colors.dart';

class WhatsAppGlyph extends StatelessWidget {
  const WhatsAppGlyph({
    super.key,
    this.size = 20,
    this.color = DesignColors.whatsApp,
    this.onColor = DesignColors.onPrimary,
  });

  final double size;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(size: Size.square(size), painter: _BubblePainter(color)),
            Icon(Icons.call_rounded, size: size * 0.52, color: onColor),
          ],
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = Offset(w / 2, w / 2);
    final r = w * 0.46;
    final path = Path()
      ..addOval(Rect.fromCircle(center: c, radius: r))
      ..moveTo(w * 0.16, w * 0.70)
      ..lineTo(w * 0.04, w * 0.97)
      ..lineTo(w * 0.32, w * 0.86)
      ..close();
    canvas.drawPath(path, Paint()..color = color..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) => old.color != color;
}
