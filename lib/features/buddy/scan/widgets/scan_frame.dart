import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design/design.dart';
import '../../shared/buddy_look.dart';

class ScanFrame extends StatefulWidget {
  const ScanFrame({super.key, required this.size, this.color = BuddyLook.scanTeal, this.sweep = false});

  final double size;
  final Color color;
  final bool sweep;

  @override
  State<ScanFrame> createState() => _ScanFrameState();
}

class _ScanFrameState extends State<ScanFrame> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  static const double _lineLo = 0.12;
  static const double _lineHi = 0.88;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = widget.sweep && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!animate && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void didUpdateWidget(ScanFrame old) {
    super.didUpdateWidget(old);
    if (widget.sweep != old.sweep) didChangeDependencies();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = DS.s(widget.size);
    return ExcludeSemantics(
      child: SizedBox(
        width: box,
        height: box,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _BracketPainter(color: widget.color, arm: DS.s(54), stroke: DS.s(5), radius: DS.s(22)))),
            if (widget.sweep)
              AnimatedBuilder(
                animation: _ctrl,
                builder: (_, _) {
                  final t = _ctrl.isAnimating ? _lineLo + (_lineHi - _lineLo) * Curves.easeInOut.transform(_ctrl.value) : 0.5;
                  return Positioned(
                    left: DS.s(18),
                    right: DS.s(18),
                    top: box * t - DS.s(1.5),
                    height: DS.s(3),
                    child: DecoratedBox(
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, widget.color, Colors.transparent])),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter({required this.color, required this.arm, required this.stroke, required this.radius});

  final Color color;
  final double arm;
  final double stroke;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final c = stroke / 2;
    final r = radius - c;
    final corner = Path()
      ..moveTo(c, arm)
      ..lineTo(c, radius)
      ..arcTo(Rect.fromLTWH(c, c, 2 * r, 2 * r), math.pi, math.pi / 2, false)
      ..lineTo(arm, c);
    for (final (sx, sy, dx, dy) in [(1.0, 1.0, 0.0, 0.0), (-1.0, 1.0, size.width, 0.0), (1.0, -1.0, 0.0, size.height), (-1.0, -1.0, size.width, size.height)]) {
      canvas.save();
      canvas.translate(dx, dy);
      canvas.scale(sx, sy);
      canvas.drawPath(corner, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.color != color || old.arm != arm || old.stroke != stroke || old.radius != radius;
}
