import 'package:flutter/material.dart';

import '../../design/design.dart';

class SplashHero extends StatefulWidget {
  const SplashHero({super.key});

  static const Key titleKey = ValueKey('splash_title');
  static const String brand = 'Bakhli';
  static const String tagline = 'Plan your next trip';

  @override
  State<SplashHero> createState() => _SplashHeroState();
}

class _ShimmerSlide extends GradientTransform {
  const _ShimmerSlide(this.t);
  final double t;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}

class _SplashHeroState extends State<SplashHero> with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _idle;
  bool _started = false;

  Animation<double> _span(int startMs, int ms, Curve curve) => CurvedAnimation(
        parent: _intro,
        curve: Interval(startMs / SplashTiming.introMs,
            (startMs + ms) / SplashTiming.introMs,
            curve: curve),
      );

  late final Animation<double> _glow = _span(0, SplashTiming.glowMs, Curves.fastOutSlowIn);
  late final Animation<double> _word =
      _span(SplashTiming.wordDelayMs, SplashTiming.wordMs, const Cubic(0.16, 1, 0.3, 1));
  late final Animation<double> _shimmer =
      _span(SplashTiming.shimmerDelayMs, SplashTiming.shimmerMs, Curves.easeInOut);
  late final Animation<double> _tag =
      _span(SplashTiming.tagDelayMs, SplashTiming.tagMs, Curves.fastOutSlowIn);

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
        vsync: this, duration: const Duration(milliseconds: SplashTiming.introMs));
    _idle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: SplashTiming.breatheMs));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (KitMotion.reduce(context)) {
      _intro.duration = const Duration(milliseconds: SplashTiming.reducedFadeMs);
      _intro.forward();
    } else {
      _intro.forward();
      _idle.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = KitMotion.reduce(context);
    final width = MediaQuery.sizeOf(context).width;
    final glowSize = SplashType.glowSize(width);

    return Semantics(
      container: true,
      header: true,
      label: '${SplashHero.brand}. ${SplashHero.tagline}',
      child: ExcludeSemantics(
        child: ColoredBox(
          color: SplashInk.night,
          child: Stack(
            children: [
              Align(
                alignment: const Alignment(0, -0.08),
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_intro, _idle]),
                    builder: (_, child) {
                      final breathe = Curves.easeInOut.transform(_idle.value);
                      final intro = reduce ? _intro.value : _glow.value;
                      return Opacity(
                        opacity: intro * (1 - 0.15 * breathe),
                        child: Transform.scale(
                          scale: (reduce ? 1.0 : 0.8 + 0.2 * intro) * (1 + 0.07 * breathe),
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: glowSize,
                      height: glowSize,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [SplashInk.glowCore, SplashInk.glowMid, SplashInk.glowEdge],
                          stops: [0, 0.33, 0.7],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _wordmark(SplashType.wordSize(width), reduce),
                        const SizedBox(height: 14),
                        _tagline(SplashType.tagSize(width), reduce),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wordmark(double size, bool reduce) {
    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _idle]),
      builder: (context, _) {
        final t = reduce ? 1.0 : _word.value;
        final float = reduce ? 0.0 : -4 * Curves.easeInOut.transform(_idle.value);
        return Opacity(
          opacity: reduce ? _intro.value : t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 24 + float),
            child: Transform.scale(
              scale: 0.94 + 0.06 * t,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15)),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ShaderMask(
                    blendMode: BlendMode.srcATop,
                    shaderCallback: (rect) => LinearGradient(
                      colors: const [
                        SplashInk.shimmerClear,
                        SplashInk.shimmer,
                        SplashInk.shimmerClear,
                      ],
                      stops: const [0.35, 0.5, 0.65],
                      transform: _ShimmerSlide(reduce ? 0 : _shimmer.value),
                    ).createShader(rect),
                    child: Text(
                      SplashHero.brand,
                      key: SplashHero.titleKey,
                      maxLines: 1,
                      style: TypeTokens.style(
                        size,
                        FontWeight.w800,
                        color: SplashInk.white,
                        height: 1.0,
                        letterSpacing: reduce ? 6 : 14 - 8 * t,
                      ).copyWith(shadows: const [
                        Shadow(color: SplashInk.textShadow, blurRadius: 30, offset: Offset(0, 8)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tagline(double size, bool reduce) {
    return AnimatedBuilder(
      animation: _intro,
      builder: (context, child) {
        final t = reduce ? _intro.value : _tag.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, reduce ? 0 : (1 - t) * 14), child: child),
        );
      },
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.3)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            SplashHero.tagline,
            maxLines: 1,
            style: TypeTokens.style(size, FontWeight.w500,
                color: SplashInk.tagline, letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }
}
