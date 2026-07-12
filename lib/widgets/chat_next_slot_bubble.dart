import 'package:flutter/material.dart';
import '../config/app_colors.dart';

// The renter/owner's next action, rendered as the last item in the message
// thread instead of a bar fixed to the bottom of the screen — so the "+" is
// always exactly where the next message will appear. Tapping it opens the
// same ChatPlusMenuSheet the fixed composer used to open; only the trigger's
// position changed; the sheet-picking mechanism is untouched.
class ChatNextSlotBubble extends StatelessWidget {
  final VoidCallback onTap;
  final bool sending;

  const ChatNextSlotBubble({super.key, required this.onTap, required this.sending});

  static const _radius = BorderRadius.only(
    topLeft: Radius.circular(14),
    topRight: Radius.circular(14),
    bottomLeft: Radius.circular(14),
    bottomRight: Radius.circular(3),
  );

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: _radius,
            onTap: sending ? null : onTap,
            child: CustomPaint(
              painter: _DashedRRectPainter(color: AppColors.primary.withValues(alpha: 0.55), radius: _radius),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.055),
                  borderRadius: _radius,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (sending) ...[
                    const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    const Text('Sending…',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ] else ...[
                    const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 5),
                    const Text('Ask something',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ],
                ]),
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
      ..strokeWidth = 1.6;
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
