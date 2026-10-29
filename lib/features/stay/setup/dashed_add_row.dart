import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../config/app_colors.dart';
import 'stay_option_sets.dart';

class DashedAddRow extends StatelessWidget {
  final String label;
  final String counter;
  final bool enabled;
  final VoidCallback onTap;
  final Color accent;

  const DashedAddRow({
    super.key,
    required this.label,
    required this.counter,
    required this.enabled,
    required this.onTap,
    this.accent = StayColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: accent.withValues(alpha: 0.5)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Icon(Iconsax.add, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: accent)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(counter,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppColors.textLight)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  const _DashedBorderPainter({required this.color});

  static const double _stroke = 1.5;
  static const double _dash = 6;
  static const double _gap = 4;
  static const double _radius = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(_radius)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = (d + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color;
}
