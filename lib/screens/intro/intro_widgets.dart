import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../config/app_colors.dart';
import 'intro_strings.dart';

double introOffset(ValueListenable<double> progress, int index) => progress.value - index;

bool introReduceMotion(BuildContext context) => MediaQuery.disableAnimationsOf(context);

class IntroSlideCanvas {
  IntroSlideCanvas._();
  static const Size size = Size(280, 240);
}

class IntroInteractionNotification extends Notification {
  const IntroInteractionNotification();
}

class IntroPageChrome extends StatefulWidget {
  const IntroPageChrome({
    super.key,
    required this.index,
    required this.isActive,
    required this.progress,
    required this.copy,
    required this.graphic,
    required this.bottomReserve,
    required this.topReserve,
  });

  final int index;
  final bool isActive;
  final ValueListenable<double> progress;
  final IntroSlideCopy copy;
  final Widget graphic;
  final double bottomReserve;
  final double topReserve;

  @override
  State<IntroPageChrome> createState() => _IntroPageChromeState();
}

class _IntroPageChromeState extends State<IntroPageChrome> with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  bool _reduce = false;
  bool _initialised = false;

  static const _eyebrowIn = Interval(0.0, 0.5, curve: Curves.easeOutCubic);
  static const _headlineIn = Interval(0.15, 0.75, curve: Curves.easeOutCubic);
  static const _subIn = Interval(0.3, 0.9, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = introReduceMotion(context);
    final first = !_initialised;
    _initialised = true;
    _reduce = reduce;
    if (_reduce) {
      _entrance.stop();
      _entrance.value = 1;
    } else if (first && widget.isActive) {
      _entrance.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant IntroPageChrome old) {
    super.didUpdateWidget(old);
    if (!old.isActive && widget.isActive) {
      if (_reduce) {
        _entrance.value = 1;
      } else if (_entrance.value < 1) {
        _entrance.forward(from: 0);
      }
    } else if (old.isActive && !widget.isActive) {
      _entrance.stop();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Widget _rise(Interval interval, Widget child) {
    final v = interval.transform(_entrance.value);
    return Opacity(
      opacity: v.clamp(0.0, 1.0),
      child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.copy;
    final textScale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 1.3);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = math.max(0.0, constraints.maxWidth - 48);
        final maxH = math.max(0.0, constraints.maxHeight - widget.topReserve - widget.bottomReserve);
        var graphicH = (maxH * 0.52).clamp(140.0, 260.0);
        graphicH = math.min(graphicH, maxH - 150 * textScale);
        graphicH = math.max(graphicH, 80.0);
        final graphicW = math.min(maxW, 320.0);

        final eyebrow = Text(
          copy.eyebrow,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.2,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        );
        final headline = SizedBox(
          width: maxW,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: maxW,
              child: Text(
                copy.headline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.22,
                  letterSpacing: -0.3,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
        final sub = Text(
          copy.sub,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.4,
            color: Colors.white.withValues(alpha: 0.88),
          ),
        );

        final textBlock = AnimatedBuilder(
          animation: _entrance,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _rise(_eyebrowIn, eyebrow),
              const SizedBox(height: 10),
              _rise(_headlineIn, headline),
              const SizedBox(height: 8),
              _rise(_subIn, sub),
            ],
          ),
        );

        final parallaxText = ValueListenableBuilder<double>(
          valueListenable: widget.progress,
          child: textBlock,
          builder: (context, value, child) {
            final offset = value - widget.index;
            final opacity = (1 - offset.abs() * 1.4).clamp(0.0, 1.0);
            final dx = _reduce ? 0.0 : -offset * constraints.maxWidth * 0.12;
            return Opacity(
              opacity: opacity,
              child: Transform.translate(offset: Offset(dx, 0), child: child),
            );
          },
        );

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(24, widget.topReserve, 24, widget.bottomReserve),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: maxH),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: graphicW,
                    height: graphicH,
                    child: RepaintBoundary(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox.fromSize(size: IntroSlideCanvas.size, child: widget.graphic),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  parallaxText,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class IntroPillButton extends StatelessWidget {
  const IntroPillButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class IntroCtaButton extends StatefulWidget {
  const IntroCtaButton({super.key, required this.progress, required this.isLast, required this.onTap});

  final ValueListenable<double> progress;
  final bool isLast;
  final VoidCallback onTap;

  static const List<Color> accents = [
    AppColors.primary,
    AppColors.tripDark,
    AppColors.stayDark,
    AppColors.taxiDark,
    AppColors.taxiDark,
    AppColors.textDark,
  ];

  static const int _lastIndex = 5;

  @override
  State<IntroCtaButton> createState() => _IntroCtaButtonState();
}

class _IntroCtaButtonState extends State<IntroCtaButton> with SingleTickerProviderStateMixin {
  late final AnimationController _loop;
  bool _reduce = false;
  bool _pressed = false;

  static const _plain = LinearGradient(colors: [Colors.white, Colors.white]);
  static const _final = LinearGradient(colors: [AppColors.tripDark, AppColors.trip]);

  @override
  void initState() {
    super.initState();
    _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = introReduceMotion(context);
    _syncLoop();
  }

  @override
  void didUpdateWidget(covariant IntroCtaButton old) {
    super.didUpdateWidget(old);
    if (old.isLast != widget.isLast) _syncLoop();
  }

  void _syncLoop() {
    if (widget.isLast && !_reduce) {
      if (!_loop.isAnimating) _loop.repeat(reverse: true);
    } else {
      _loop.stop();
      _loop.value = 0;
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  void _setPressed(bool v) {
    if (_pressed == v) return;
    setState(() => _pressed = v);
  }

  static Color _accentAt(double p) {
    final c = p.clamp(0.0, IntroCtaButton._lastIndex.toDouble());
    final i = c.floor();
    final j = math.min(i + 1, IntroCtaButton._lastIndex);
    return Color.lerp(IntroCtaButton.accents[i], IntroCtaButton.accents[j], c - i)!;
  }

  Widget _plainLabel() {
    return ValueListenableBuilder<double>(
      key: const ValueKey('cta_next'),
      valueListenable: widget.progress,
      builder: (context, value, _) {
        final color = _accentAt(value);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                IntroStrings.next,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 15.5, fontWeight: FontWeight.w800, color: color),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 18, color: color),
          ],
        );
      },
    );
  }

  Widget _finalLabel() {
    return Row(
      key: const ValueKey('cta_start'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Iconsax.routing_2, size: 18, color: Colors.white),
        const SizedBox(width: 8),
        const Flexible(
          child: Text(
            IntroStrings.getStarted,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedBuilder(
          animation: _loop,
          child: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
          builder: (context, child) {
            final tri = 1 - (2 * _loop.value - 1).abs();
            final dx = 4 * Curves.easeInOutSine.transform(tri);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = widget.isLast;
    final radius = BorderRadius.circular(14);

    final body = AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: isLast ? _final : _plain,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLast ? 0.0 : 0.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: isLast ? _finalLabel() : _plainLabel(),
          ),
        ),
      ),
    );

    final glowing = AnimatedBuilder(
      animation: _loop,
      child: body,
      builder: (context, child) {
        if (!isLast) return child!;
        final g = _reduce ? 0.5 : Curves.easeInOutSine.transform(_loop.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: AppColors.trip.withValues(alpha: 0.25 + 0.20 * g),
                blurRadius: 8 + 10 * g,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        );
      },
    );

    return Semantics(
      button: true,
      label: isLast ? IntroStrings.getStarted : IntroStrings.next,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1.0,
          duration: Duration(milliseconds: _pressed ? 100 : 220),
          curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
          child: SizedBox.expand(child: glowing),
        ),
      ),
    );
  }
}

class _ThreadGeometry {
  _ThreadGeometry(this.size, this.count) {
    final y = size.height / 2 - 3;
    const x0 = 11.0;
    final x1 = math.max(x0 + 1, size.width - 30);
    path = Path()
      ..moveTo(x0, y)
      ..quadraticBezierTo((x0 + x1) / 2, y + 12, x1, y);
    metric = path.computeMetrics().first;
    length = metric.length;
    stops = [
      for (var k = 0; k < count; k++) metric.getTangentForOffset(length * k / (count - 1))!.position,
    ];
    dashed = Path();
    for (var d = 0.0; d < length; d += 11) {
      dashed.addPath(metric.extractPath(d, math.min(d + 6, length)), Offset.zero);
    }
  }

  final Size size;
  final int count;
  late final Path path;
  late final ui.PathMetric metric;
  late final double length;
  late final List<Offset> stops;
  late final Path dashed;

  ui.Tangent tangentAt(double page) {
    final t = (page / (count - 1)).clamp(0.0, 1.0);
    return metric.getTangentForOffset(length * t)!;
  }
}

class _ThreadPainter extends CustomPainter {
  _ThreadPainter({
    required this.geometry,
    required this.fill,
    required this.currentPage,
    required this.showFill,
  }) : super(repaint: fill);

  final _ThreadGeometry geometry;
  final Animation<double> fill;
  final int currentPage;
  final bool showFill;

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    canvas.drawPath(
      g.dashed,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.35),
    );

    final f = fill.value;
    if (showFill && f > 0 && currentPage < g.count - 1) {
      final seg = g.length / (g.count - 1);
      final from = seg * currentPage;
      canvas.drawPath(
        g.metric.extractPath(from, from + seg * f.clamp(0.0, 1.0)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.9),
      );
    }

    final halo = Paint()..color = Colors.white.withValues(alpha: 0.35);
    final solid = Paint()..color = Colors.white;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withValues(alpha: 0.6);
    for (var k = 0; k < g.count; k++) {
      final c = g.stops[k];
      if (k <= currentPage) {
        canvas.drawCircle(c, 6.5, halo);
        canvas.drawCircle(c, 4.5, solid);
      } else {
        canvas.drawCircle(c, 4.5, ring);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ThreadPainter old) =>
      old.geometry != geometry || old.currentPage != currentPage || old.showFill != showFill || old.fill != fill;
}

class IntroJourneyThread extends StatefulWidget {
  const IntroJourneyThread({
    super.key,
    required this.progress,
    required this.currentPage,
    required this.pageCount,
    required this.autoplayFill,
    required this.onStopTap,
    required this.onTaxiTap,
  });

  final ValueListenable<double> progress;
  final int currentPage;
  final int pageCount;
  final Animation<double> autoplayFill;
  final ValueChanged<int> onStopTap;
  final VoidCallback onTaxiTap;

  @override
  State<IntroJourneyThread> createState() => _IntroJourneyThreadState();
}

class _IntroJourneyThreadState extends State<IntroJourneyThread> with SingleTickerProviderStateMixin {
  late final AnimationController _wiggle;
  late Listenable _taxiListenable;
  _ThreadGeometry? _geo;
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    _wiggle = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
    _taxiListenable = Listenable.merge([widget.progress, _wiggle]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = introReduceMotion(context);
  }

  @override
  void didUpdateWidget(covariant IntroJourneyThread old) {
    super.didUpdateWidget(old);
    if (old.progress != widget.progress) {
      _taxiListenable = Listenable.merge([widget.progress, _wiggle]);
    }
    if (old.pageCount != widget.pageCount) _geo = null;
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  void _onTaxiTap() {
    if (!_reduce) _wiggle.forward(from: 0);
    widget.onTaxiTap();
  }

  _ThreadGeometry _geometryFor(Size size) {
    final g = _geo;
    if (g != null && g.size == size && g.count == widget.pageCount) return g;
    return _geo = _ThreadGeometry(size, widget.pageCount);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final geo = _geometryFor(size);
        final last = widget.pageCount - 1;
        final isLast = widget.currentPage >= last;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _ThreadPainter(
                    geometry: geo,
                    fill: widget.autoplayFill,
                    currentPage: widget.currentPage,
                    showFill: !_reduce && !isLast,
                  ),
                ),
              ),
            ),
            for (var k = 0; k < widget.pageCount; k++)
              Positioned(
                left: geo.stops[k].dx - 22,
                top: 0,
                width: 44,
                height: size.height,
                child: Semantics(
                  button: true,
                  label: 'Chapter ${k + 1}',
                  child: GestureDetector(
                    key: Key('intro_stop_$k'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onStopTap(k),
                  ),
                ),
              ),
            if (isLast)
              Positioned(
                left: geo.stops[last].dx + 12,
                top: geo.stops[last].dy - 16,
                child: const IgnorePointer(child: Icon(Iconsax.flag, size: 12, color: Colors.white)),
              ),
            AnimatedBuilder(
              animation: _taxiListenable,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Iconsax.car, size: 13, color: AppColors.trip),
              ),
              builder: (context, child) {
                final page = _reduce
                    ? widget.currentPage.toDouble()
                    : widget.progress.value.clamp(0.0, last.toDouble());
                final tangent = geo.tangentAt(page);
                final pos = tangent.position;
                final base = math.atan2(tangent.vector.dy, tangent.vector.dx).clamp(-0.3, 0.3);
                final wiggle = 0.12 * math.sin(4 * math.pi * _wiggle.value);
                return Positioned(
                  left: pos.dx - 17,
                  top: pos.dy - 17,
                  width: 34,
                  height: 34,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onTaxiTap,
                    child: Center(child: Transform.rotate(angle: base + wiggle, child: child)),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class IntroPingRing extends StatelessWidget {
  const IntroPingRing({
    super.key,
    required this.phase,
    this.baseSize = 18,
    this.maxScale = 3.0,
    this.color = Colors.white,
  });

  final double phase;
  final double baseSize;
  final double maxScale;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.square(
        dimension: baseSize,
        child: CustomPaint(painter: _PingPainter(phase: phase, maxScale: maxScale, color: color)),
      ),
    );
  }
}

class _PingPainter extends CustomPainter {
  _PingPainter({required this.phase, required this.maxScale, required this.color});

  final double phase;
  final double maxScale;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = phase.clamp(0.0, 1.0);
    final alpha = 0.55 * (1 - p);
    if (alpha <= 0) return;
    final scale = 0.4 + (maxScale - 0.4) * p;
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2 * scale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = color.withValues(alpha: alpha * color.a),
    );
  }

  @override
  bool shouldRepaint(covariant _PingPainter old) =>
      old.phase != phase || old.maxScale != maxScale || old.color != color;
}

class IntroSparkBurst extends StatelessWidget {
  const IntroSparkBurst({
    super.key,
    required this.t,
    this.count = 6,
    this.radius = 30,
    this.colors = const [Colors.white],
  });

  final double t;
  final int count;
  final double radius;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.square(
        dimension: radius * 2,
        child: CustomPaint(painter: _SparkPainter(t: t, count: count, radius: radius, colors: colors)),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.t, required this.count, required this.radius, required this.colors});

  final double t;
  final int count;
  final double radius;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1 || count <= 0 || colors.isEmpty) return;
    final center = size.center(Offset.zero);
    final travel = Curves.easeOutCubic.transform(t);
    final alpha = 1 - t;
    final dot = 2.4 * (1 - 0.5 * t);
    final paint = Paint();
    for (var k = 0; k < count; k++) {
      final angle = 2 * math.pi * k / count - math.pi / 2;
      final reach = radius * (k.isEven ? 1.0 : 0.78) * travel;
      final c = colors[k % colors.length];
      paint.color = c.withValues(alpha: c.a * alpha);
      canvas.drawCircle(center + Offset(math.cos(angle), math.sin(angle)) * reach, dot, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.t != t || old.count != count || old.radius != radius || !listEquals(old.colors, colors);
}

class IntroSlashPainter extends CustomPainter {
  IntroSlashPainter({required this.t, this.color = AppColors.error});

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = t.clamp(0.0, 1.0);
    if (p <= 0) return;
    final start = Offset(size.width * 0.08, size.height * 0.85);
    final end = Offset(size.width * 0.92, size.height * 0.15);
    canvas.drawLine(
      start,
      Offset.lerp(start, end, p)!,
      Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant IntroSlashPainter old) => old.t != t || old.color != color;
}
