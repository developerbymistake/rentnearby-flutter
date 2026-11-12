import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../tokens/alpha_tokens.dart';
import '../tokens/design_colors.dart';
import '../tokens/shadow_tokens.dart';
import 'motion_kit.dart';
import 'template_motion.dart';

class TemplateEntranceOnce extends StatefulWidget {
  const TemplateEntranceOnce({
    super.key,
    required this.child,
    this.index = 0,
    this.count = 1,
    this.offset = 30,
    this.duration = const Duration(milliseconds: 600),
  });

  final Widget child;
  final int index;
  final int count;
  final double offset;
  final Duration duration;

  @override
  State<TemplateEntranceOnce> createState() => _TemplateEntranceOnceState();
}

class _TemplateEntranceOnceState extends State<TemplateEntranceOnce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(duration: widget.duration, vsync: this);
  late final Animation<double> _animation = templateInterval(
    _controller,
    math.min(widget.index, math.max(widget.count - 1, 0)),
    math.max(widget.count, 1),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TemplateEntrance(
      animation: _animation,
      animationController: _controller,
      offset: widget.offset,
      child: widget.child,
    );
  }
}

class TemplateMiniRing extends StatelessWidget {
  const TemplateMiniRing({
    super.key,
    required this.percent,
    required this.colors,
    this.size = 48,
    this.stroke = 6,
    this.progress = 1,
    this.track = DesignColors.scaffold,
  });

  final int percent;
  final List<Color> colors;
  final double size;
  final double stroke;
  final double progress;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MiniRingPainter(
          fraction: (percent.clamp(0, 100) / 100) * progress,
          colors: colors,
          stroke: stroke,
          track: track,
        ),
      ),
    );
  }
}

class _MiniRingPainter extends CustomPainter {
  _MiniRingPainter({
    required this.fraction,
    required this.colors,
    required this.stroke,
    required this.track,
  });

  final double fraction;
  final List<Color> colors;
  final double stroke;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (fraction <= 0) return;
    final start = -math.pi / 2;
    final paint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: colors,
        transform: GradientRotation(start),
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, start, math.pi * 2 * fraction, false, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniRingPainter old) =>
      old.fraction != fraction || old.colors != colors || old.stroke != stroke || old.track != track;
}

class TemplateRoundButton extends StatelessWidget {
  const TemplateRoundButton({super.key, required this.icon, required this.onTap, this.size = 40});

  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final on = onTap != null;
    return PressScale(
      enabled: on,
      child: SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: on ? DesignColors.surface : DesignColors.scaffold,
            shape: BoxShape.circle,
            boxShadow: on ? ShadowTokens.elev2 : null,
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              splashColor: DesignColors.tint(DesignColors.primary, Alpha.soft),
              highlightColor: Colors.transparent,
              child: Icon(icon,
                  size: 22, color: on ? DesignColors.primary : DesignColors.textDisabled),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
