import 'package:flutter/material.dart';
import 'package:bakhli/design/template/fitness_app_theme.dart';
import '../design/tokens/alpha_tokens.dart';

class ChatNextSlotBubble extends StatelessWidget {
  final VoidCallback onTap;
  final bool sending;
  final Color accent;

  const ChatNextSlotBubble({super.key, required this.onTap, required this.sending, this.accent = FitnessAppTheme.nearlyDarkBlue});

  static const _radius = BorderRadius.only(
    topLeft: Radius.circular(16),
    topRight: Radius.circular(16),
    bottomLeft: Radius.circular(16),
    bottomRight: Radius.circular(8),
  );

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: AnimatedOpacity(
          opacity: sending ? 0.55 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.fastOutSlowIn,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: _radius,
              highlightColor: Colors.transparent,
              onTap: sending ? null : onTap,
              child: CustomPaint(
                painter: _DashedRRectPainter(color: accent.withValues(alpha: Alpha.strong), radius: _radius),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: Alpha.hairline),
                    borderRadius: _radius,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, size: 16, color: accent),
                    const SizedBox(width: 5),
                    Text('Ask something',
                        style: FitnessAppTheme.body2.copyWith(fontWeight: FontWeight.w600, color: accent)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final BorderRadius radius;
  static const double _dashWidth = 4;
  static const double _dashGap = 3;

  const _DashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius.toRRect(Offset.zero & size);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + _dashWidth;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + _dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
