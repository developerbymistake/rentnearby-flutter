import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/design.dart';
import '../../design/extra/ext_auth.dart';
import 'intro_strings.dart';

double introOffset(ValueListenable<double> progress, int index) => progress.value - index;

bool introReduceMotion(BuildContext context) => MediaQuery.disableAnimationsOf(context);

class IntroSlideCanvas {
  IntroSlideCanvas._();
  static const Size size = Size(324, IntroCard3D.height);
}

class IntroInteractionNotification extends Notification {
  const IntroInteractionNotification();
}

class IntroTones {
  IntroTones._();

  static final List<ListingTone> page = [
    ListingTone.indigo,
    ListingTone.indigo,
    ListingTone.forest,
    ListingTone.coral,
    ListingTone.indigo,
    ListingTone.indigo,
  ];

  static final List<ListingTone> card = [
    ListingTone.indigo,
    ListingTone.indigo,
    ListingTone.forest,
    ListingTone.coral,
    ListingTone.indigo,
    ListingTone.cD,
  ];

  static const List<String> art = [
    ListingArt.airplane,
    ListingArt.compass,
    ListingArt.bed,
    AuthInk.automobile,
    ListingArt.sunrise,
    ListingArt.backpack,
  ];

  static ListingTone at(double p) {
    final c = p.clamp(0.0, page.length - 1.0);
    final i = c.floor();
    final j = math.min(i + 1, page.length - 1);
    if (i == j || c == i) return page[i];
    return AuthInk.lerp(page[i], page[j], c - i);
  }

  static Color background(double p) {
    final c = p.clamp(0.0, page.length - 1.0);
    final i = c.floor();
    final j = math.min(i + 1, page.length - 1);
    return Color.lerp(AuthInk.pageOf(page[i]), AuthInk.pageOf(page[j]), c - i)!;
  }
}

/// One intro page: big 3D art over a halo, eyebrow, headline, sub, then the slide card.
/// Layers move at different speeds while paging, like the template introduction animation.
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

  static const _artIn = Interval(0.0, 0.6, curve: Curves.fastOutSlowIn);
  static const _eyebrowIn = Interval(0.1, 0.6, curve: Curves.easeOutCubic);
  static const _headlineIn = Interval(0.2, 0.75, curve: Curves.easeOutCubic);
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
    } else if (first) {
      _entrance.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant IntroPageChrome old) {
    super.didUpdateWidget(old);
    if (!old.isActive && widget.isActive) {
      if (_reduce) {
        _entrance.value = 1;
      } else if (_entrance.value < 1) {
        _entrance.forward();
      }
    } else if (old.isActive && !widget.isActive) {
      _entrance.stop();
      _entrance.value = 1;
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
      child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: child),
    );
  }

  double _textHeight(BuildContext context, IntroSlideCopy copy, double width) {
    final scaler = MediaQuery.textScalerOf(context);
    double h(String t, TextStyle st, int lines) {
      final tp = TextPainter(
        text: TextSpan(text: t, style: st),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: lines,
      )..layout(maxWidth: width);
      final r = tp.height;
      tp.dispose();
      return r;
    }

    return h(copy.eyebrow, Ink3D.text(12, FontWeight.w700, DesignColors.onPrimary, letterSpacing: 1.4), 1) +
        6 +
        h(copy.headline, Ink3D.text(26, FontWeight.w700, Ink3D.title, height: 1.2, letterSpacing: 0), 2) +
        6 +
        h(copy.sub, Ink3D.text(14.5, FontWeight.w400, Ink3D.sub, height: 1.45, letterSpacing: 0), 3);
  }

  Widget _layer(double factor, double width, Widget child, {bool fade = false}) {
    return ValueListenableBuilder<double>(
      valueListenable: widget.progress,
      child: child,
      builder: (context, value, child) {
        final offset = (value - widget.index).clamp(-1.5, 1.5);
        final dx = _reduce ? 0.0 : -offset * width * factor;
        final moved = Transform.translate(offset: Offset(dx, 0), child: child);
        if (!fade) return moved;
        return Opacity(opacity: (1 - offset.abs() * 1.2).clamp(0.0, 1.0), child: moved);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = widget.copy;
    final tone = IntroTones.page[widget.index];
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final avail = math.max(0.0, constraints.maxHeight - widget.topReserve - widget.bottomReserve);
        final textH = _textHeight(context, copy, w - 52);
        final artH = (avail - textH - IntroSlideCanvas.size.height).clamp(96.0, 190.0);

        final art = AnimatedBuilder(
          animation: _entrance,
          builder: (context, child) {
            final v = _artIn.transform(_entrance.value);
            return Opacity(opacity: v.clamp(0.0, 1.0), child: Transform.scale(scale: 0.85 + 0.15 * v, child: child));
          },
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ExcludeSemantics(
              child: Art3D(asset: IntroTones.art[widget.index], size: 180, halo: 200, haloColor: tone.halo, shadowBlur: 8, shadowOffset: const Offset(8, 12), shadowAlpha: 0.25),
            ),
          ),
        );

        final text = AnimatedBuilder(
          animation: _entrance,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _rise(_eyebrowIn, Text(copy.eyebrow, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(12, FontWeight.w700, tone.g2, letterSpacing: 1.4))),
              const SizedBox(height: 6),
              _rise(
                _headlineIn,
                Semantics(
                  header: true,
                  child: Text(copy.headline, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(26, FontWeight.w700, Ink3D.title, height: 1.2, letterSpacing: 0)),
                ),
              ),
              const SizedBox(height: 6),
              _rise(_subIn, Text(copy.sub, maxLines: 3, overflow: TextOverflow.ellipsis, style: Ink3D.text(14.5, FontWeight.w400, Ink3D.sub, height: 1.45, letterSpacing: 0))),
            ],
          ),
        );

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.only(top: widget.topReserve, bottom: widget.bottomReserve),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: artH, child: _layer(0.6, w, Center(child: art))),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: textH),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(padding: const EdgeInsets.fromLTRB(26, 0, 26, 0), child: _layer(0.25, w, text, fade: true)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: SizedBox(height: IntroSlideCanvas.size.height, child: RepaintBoundary(child: widget.graphic)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class IntroPillButton extends StatelessWidget {
  const IntroPillButton({super.key, required this.label, required this.onTap, this.color});

  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Tap3D(
      onTap: onTap,
      label: label,
      exclude: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(color: DesignColors.onPrimary, borderRadius: BorderRadius.circular(20), boxShadow: Ink3D.softShadow),
        child: Text(label, maxLines: 1, style: Ink3D.text(14, FontWeight.w700, color ?? ListingTone.indigo.text)),
      ),
    );
  }
}

class IntroCtaButton extends StatelessWidget {
  const IntroCtaButton({super.key, required this.progress, required this.isLast, required this.onTap});

  final ValueListenable<double> progress;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = isLast ? IntroStrings.getStarted : IntroStrings.next;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, p, _) {
              final tone = IntroTones.at(p);
              return DecoratedBox(
                decoration: BoxDecoration(gradient: tone.gradient, borderRadius: BorderRadius.circular(27), boxShadow: Form3D.glow(tone)),
                child: SizedBox.expand(
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(a), child: child),
                      ),
                      child: Padding(
                        key: ValueKey(isLast ? 'cta_start' : 'cta_next'),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Ink3D.text(17, FontWeight.w700, DesignColors.onPrimary)),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
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
  late final AnimationController _wiggle = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
  bool _reduce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = introReduceMotion(context);
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

  @override
  Widget build(BuildContext context) {
    final last = widget.pageCount - 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ValueListenableBuilder<double>(
                valueListenable: widget.progress,
                builder: (context, p, _) {
                  final page = _reduce ? widget.currentPage.toDouble() : p.clamp(0.0, last.toDouble());
                  return CustomPaint(painter: IntroThreadPainter(tone: IntroTones.at(page), page: page, count: widget.pageCount, current: widget.currentPage));
                },
              ),
            ),
            for (var k = 0; k < widget.pageCount; k++)
              Positioned(
                left: IntroThreadPainter.xOf(size, widget.pageCount, k.toDouble()) - 22,
                top: 0,
                width: 44,
                height: size.height,
                child: Semantics(
                  button: true,
                  label: 'Chapter ${k + 1}',
                  child: GestureDetector(key: Key('intro_stop_$k'), behavior: HitTestBehavior.opaque, onTap: () => widget.onStopTap(k)),
                ),
              ),
            AnimatedBuilder(
              animation: Listenable.merge([widget.progress, _wiggle]),
              builder: (context, child) {
                final page = _reduce ? widget.currentPage.toDouble() : widget.progress.value.clamp(0.0, last.toDouble());
                final x = IntroThreadPainter.xOf(size, widget.pageCount, page);
                final wiggle = 0.12 * math.sin(4 * math.pi * _wiggle.value);
                return Positioned(
                  left: x - 22,
                  top: -16,
                  width: 44,
                  height: 44,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _onTaxiTap,
                    child: Transform.rotate(angle: wiggle, child: child),
                  ),
                );
              },
              child: const ExcludeSemantics(child: Art3D(asset: ListingArt.taxi, size: 44, shadowBlur: 3, shadowOffset: Offset(2, 4), shadowAlpha: 0.3)),
            ),
          ],
        );
      },
    );
  }
}

/// Shared life cycle of the six slide cards: entrance on activation, reset of taps when the page is left.
abstract class IntroSlideState<T extends StatefulWidget> extends State<T> with SingleTickerProviderStateMixin {
  late final AnimationController entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool reduce = false;
  bool _booted = false;

  bool activeOf(T w);
  void resetTaps();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduce = introReduceMotion(context);
    if (reduce) {
      entrance.stop();
      entrance.value = 1;
    } else if (!_booted) {
      if (activeOf(widget)) {
        entrance.forward(from: 0);
      } else {
        entrance.value = 1;
      }
    }
    _booted = true;
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    final was = activeOf(oldWidget);
    final now = activeOf(widget);
    if (!was && now && !reduce) entrance.forward(from: 0.3);
    if (was && !now) {
      entrance.stop();
      entrance.value = 1;
      resetTaps();
    }
  }

  void interacted() {
    HapticFeedback.selectionClick();
    const IntroInteractionNotification().dispatch(context);
  }

  /// Fades and lifts [child] in during the entrance, staggered by [step] (0..3).
  Widget reveal(int step, Widget child) {
    return AnimatedBuilder(
      animation: entrance,
      child: child,
      builder: (context, child) {
        final b = (0.15 + 0.15 * step).clamp(0.0, 0.7);
        final v = Interval(b, math.min(1.0, b + 0.45), curve: Curves.easeOutCubic).transform(entrance.value);
        return Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: child));
      },
    );
  }

  @override
  void dispose() {
    entrance.dispose();
    super.dispose();
  }
}

/// Fits the slide card into any box (pages, tests and goldens give different sizes).
class IntroSlideFrame extends StatelessWidget {
  const IntroSlideFrame({super.key, required this.index, required this.title, required this.child, this.entrance});

  final int index;
  final String title;
  final Widget child;
  final Animation<double>? entrance;

  @override
  Widget build(BuildContext context) {
    final tone = IntroTones.card[index];
    const art = [ListingArt.mountain, ListingArt.worldMap, ListingArt.hotel, ListingArt.taxi, ListingArt.calendar, ListingArt.luggage];
    return LayoutBuilder(builder: (context, c) {
      final w = c.hasBoundedWidth ? c.maxWidth : IntroSlideCanvas.size.width;
      final h = IntroSlideCanvas.size.height;
      Widget card = IntroCard3D(tone: tone, art: art[index], title: title, child: child);
      final e = entrance;
      if (e != null) {
        card = AnimatedBuilder(
          animation: e,
          child: card,
          builder: (context, child) {
            final v = const Interval(0, 0.5, curve: Curves.fastOutSlowIn).transform(e.value);
            return Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: child));
          },
        );
      }
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: SizedBox(width: w, height: h, child: MediaQuery.withNoTextScaling(child: card)),
      );
    });
  }
}

class IntroStage extends StatefulWidget {
  const IntroStage({super.key, required this.isActive, required this.builder});

  final bool isActive;
  final Widget Function(BuildContext context, AnimationController enter) builder;

  @override
  State<IntroStage> createState() => _IntroStageState();
}

class IntroStageScope extends InheritedWidget {
  const IntroStageScope({super.key, required this.loop, required super.child});

  final Animation<double> loop;

  static Animation<double> loopOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<IntroStageScope>();
    return scope?.loop ?? const AlwaysStoppedAnimation<double>(0);
  }

  @override
  bool updateShouldNotify(IntroStageScope oldWidget) => loop != oldWidget.loop;
}

class _IntroStageState extends State<IntroStage> with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400), value: widget.isActive ? 0 : 1);
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));
  bool _reduce = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _enter.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = introReduceMotion(context);
    if (_reduce) {
      _enter.value = 1;
      _loop.stop();
      _loop.value = 0;
    } else if (widget.isActive) {
      if (_enter.value < 1 && !_enter.isAnimating) _enter.forward();
      if (!_loop.isAnimating) _loop.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant IntroStage old) {
    super.didUpdateWidget(old);
    if (!old.isActive && widget.isActive) {
      if (_reduce) {
        _enter.value = 1;
      } else {
        _enter.forward(from: 0);
        _loop.repeat();
      }
    } else if (old.isActive && !widget.isActive) {
      _enter.value = 1;
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IntroStageScope(
        loop: _loop,
        child: Builder(builder: (context) => widget.builder(context, _enter)),
      );
}
