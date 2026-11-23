import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../design/design.dart';
import 'intro_strings.dart';
import 'story/intro_story_math.dart';

bool introReduceMotion(BuildContext context) => MediaQuery.disableAnimationsOf(context);

class IntroSpringCurve extends Curve {
  const IntroSpringCurve();

  static const double _span = .9;

  static double _step(double tau) {
    const k = 58.0, c = 14.5;
    final w0 = math.sqrt(k);
    final zeta = c / (2 * w0);
    final wd = w0 * math.sqrt(1 - zeta * zeta);
    final a = zeta * w0;
    return 1 - math.exp(-a * tau) * (math.cos(wd * tau) + a / wd * math.sin(wd * tau));
  }

  @override
  double transformInternal(double t) => _step(t * _span) / _step(_span);
}

class IntroPagePhysics extends PageScrollPhysics {
  const IntroPagePhysics({super.parent});

  @override
  IntroPagePhysics applyTo(ScrollPhysics? ancestor) => IntroPagePhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring => const SpringDescription(mass: 1, stiffness: 58, damping: 14.5);
}

abstract final class IntroType {
  static TextStyle get eyebrow => Ink3D.text(12, FontWeight.w700, ListingTone.indigo.g2, letterSpacing: 1.4);
  static TextStyle get headline => Ink3D.text(26, FontWeight.w700, Ink3D.title, height: 1.2, letterSpacing: 0);
  static TextStyle get sub => Ink3D.text(14.5, FontWeight.w400, Ink3D.sub, height: 1.45, letterSpacing: 0);
  static TextStyle get cta => Ink3D.text(17, FontWeight.w700, DesignColors.onPrimary);
  static TextStyle get skip => Ink3D.text(14, FontWeight.w700, ListingTone.indigo.text);
}

class IntroPanelMetrics {
  const IntroPanelMetrics(this.height, this.compact);

  final double height;
  final bool compact;

  static double get topInset => DS.s(30);
  static double get sideInset => DS.s(24);
  static double get ctaHeight => DS.s(54);
  static double get ctaBottom => DS.s(24);

  static double _h(String text, TextStyle style, TextScaler scaler, double width, int lines) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: lines)..layout(maxWidth: width);
    final h = tp.height;
    tp.dispose();
    return h;
  }

  static double blockHeight(IntroSlideCopy c, TextScaler scaler, double width, {bool compact = false}) =>
      _h(c.eyebrow, IntroType.eyebrow, scaler, width, 1) +
      DS.gv(8) +
      _h(c.headline, IntroType.headline, scaler, width, 3) +
      DS.gv(10) +
      _h(c.sub, IntroType.sub, scaler, width, compact ? 2 : 3);

  static IntroPanelMetrics measure({required double width, required double screenHeight, required double bottomInset, required TextScaler scaler}) {
    final textW = width - 2 * sideInset;
    final chrome = topInset + DS.gv(18) + ctaHeight + ctaBottom + bottomInset;
    double tallest({required bool compact}) => IntroStrings.slides.fold<double>(0.0, (m, c) => math.max(m, blockHeight(c, scaler, textW, compact: compact)));
    final cap = screenHeight * .56;
    final full = math.max(DS.s(300), chrome + tallest(compact: false));
    if (full <= cap) return IntroPanelMetrics(full, false);
    return IntroPanelMetrics(math.min(cap, math.max(DS.s(300), chrome + tallest(compact: true))), true);
  }
}

class IntroPanel extends StatelessWidget {
  const IntroPanel({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: DesignColors.onPrimary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radius(30))),
          boxShadow: DS.shadows(Ink3D.topEdge),
        ),
        child: const SizedBox.expand(),
      );
}

class IntroTextBlocks extends StatelessWidget {
  const IntroTextBlocks({super.key, required this.progress, required this.compact});

  final ValueListenable<double> progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final spaceH = _space(IntroType.headline, scaler);
    final spaceS = _space(IntroType.sub, scaler);
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      builder: (context, p, _) {
        final blocks = <Widget>[];
        for (var i = 0; i < IntroStrings.slides.length; i++) {
          final d = i.toDouble() - p;
          final a = 1.0 - math.min(1.0, d.abs() * 1.5);
          if (a <= 0) continue;
          blocks.add(_block(i, d, a, spaceH, spaceS));
        }
        return Stack(clipBehavior: Clip.none, children: blocks);
      },
    );
  }

  static double _space(TextStyle style, TextScaler scaler) {
    final tp = TextPainter(text: TextSpan(text: ' ', style: style), textDirection: TextDirection.ltr, textScaler: scaler)..layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }

  Widget _block(int i, double d, double a, double spaceH, double spaceS) {
    final copy = IntroStrings.slides[i];
    final unit = DS.s(1);
    final r = clamp01(a * 1.45);
    final eyebrow = IntroType.eyebrow;
    final eyebrowAlpha = clamp01(a * 1.5);
    final subWords = copy.sub.split(' ');
    Widget sub;
    if (compact) {
      final o = clamp01((r - .3) / .35);
      final style = IntroType.sub;
      sub = Transform.translate(
        offset: Offset(d * 130 * unit, (1 - o) * 14 * unit),
        child: Text(copy.sub, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: style.copyWith(color: style.color!.withValues(alpha: o))),
      );
    } else {
      sub = _words(subWords, IntroType.sub, spaceS, (k, n) {
        final o = clamp01((r - .3 - (k / n) * .35) / .35);
        return (o, Offset(d * 130 * unit, (1 - o) * 14 * unit));
      });
    }
    final headWords = copy.headline.split(' ');
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Column(
        key: ValueKey('intro_text_$i'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Transform.translate(
              offset: Offset(d * 40 * unit, 0),
              child: Text(copy.eyebrow, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: eyebrow.copyWith(color: eyebrow.color!.withValues(alpha: eyebrowAlpha))),
            ),
          ),
          Gap.v(8),
          Semantics(
            header: true,
            label: copy.headline,
            child: ExcludeSemantics(
              child: _words(headWords, IntroType.headline, spaceH, (k, n) {
                final o = clamp01((r - (k / n) * .5) / .5);
                return (o, Offset(d * 90 * unit, (1 - o) * 18 * unit));
              }),
            ),
          ),
          Gap.v(10),
          Semantics(label: copy.sub, child: ExcludeSemantics(child: sub)),
        ],
      ),
    );
  }

  Widget _words(List<String> words, TextStyle style, double space, (double, Offset) Function(int k, int n) motion) {
    final n = words.length;
    final base = style.color!;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: space,
      children: [
        for (var k = 0; k < n; k++)
          Builder(builder: (context) {
            final (o, off) = motion(k, n);
            return Transform.translate(
              offset: off,
              child: Text(words[k], maxLines: 1, softWrap: false, style: style.copyWith(color: base.withValues(alpha: o))),
            );
          }),
      ],
    );
  }
}

class IntroDots extends StatelessWidget {
  const IntroDots({super.key, required this.progress, required this.count});

  final ValueListenable<double> progress;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = ListingTone.indigo.g2;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, p, _) => Row(
            key: const Key('intro_dots'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) SizedBox(width: DS.s(6)),
                _dot(color, 1 - math.min(1.0, (i - p).abs())),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(Color color, double c) {
    final alpha = .55 + .45 * c;
    return Container(
      width: DS.s(6 + 12 * c),
      height: DS.s(6),
      decoration: BoxDecoration(color: color.withValues(alpha: alpha), borderRadius: DS.circular(99)),
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
    final style = IntroType.skip;
    return Tap3D(
      onTap: onTap,
      label: label,
      exclude: true,
      child: Container(
        padding: DS.sym(h: 22, v: 8),
        decoration: BoxDecoration(color: DesignColors.onPrimary.withValues(alpha: Alpha.v75), borderRadius: DS.circular(20)),
        child: Text(label, maxLines: 1, style: color == null ? style : style.copyWith(color: color)),
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
    final tone = ListingTone.indigo;
    return Semantics(
      button: true,
      label: isLast ? IntroStrings.getStarted : IntroStrings.next,
      excludeSemantics: true,
      child: PressScale(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: tone.gradient, borderRadius: DS.circular(27), boxShadow: Form3D.glow(tone)),
            child: ClipRRect(
              borderRadius: DS.circular(27),
              child: SizedBox.expand(
                child: ValueListenableBuilder<double>(
                  valueListenable: progress,
                  builder: (context, p, _) {
                    final last = smooth((p - 4.3) / .5);
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        if (last < 1) _label(IntroStrings.next, 1 - last, -18 * last),
                        if (last > 0) _label(IntroStrings.getStarted, last, 18 * (1 - last)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text, double alpha, double dy) {
    final style = IntroType.cta;
    return Transform.translate(
      offset: Offset(0, DS.s(dy)),
      child: Padding(
        padding: DS.sym(h: 16),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style.copyWith(color: style.color!.withValues(alpha: alpha))),
      ),
    );
  }
}
