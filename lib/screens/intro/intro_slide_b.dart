import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../config/app_colors.dart';
import 'intro_slide_a.dart' show introRoutePath;
import 'intro_strings.dart';
import 'intro_widgets.dart';

double _iv(double v, double a, double b, [Curve curve = Curves.linear]) =>
    curve.transform(((v - a) / (b - a)).clamp(0.0, 1.0));

TextStyle _ts(double size, FontWeight weight, Color color) =>
    TextStyle(fontFamily: 'Poppins', fontSize: size, fontWeight: weight, color: color, height: 1.25);

abstract class _SlideState<T extends StatefulWidget> extends State<T> with TickerProviderStateMixin {
  late final AnimationController entrance;
  late final AnimationController loop;
  late final AnimationController tap;
  bool reduce = false;
  bool _initialised = false;

  Duration get entranceDuration;
  Duration get loopDuration;
  Duration get tapDuration;
  bool activeOf(T w);
  ValueListenable<double> progressOf(T w);
  void resetTaps();

  bool get active => activeOf(widget);
  ValueListenable<double> get progress => progressOf(widget);

  @override
  void initState() {
    super.initState();
    entrance = AnimationController(vsync: this, duration: entranceDuration);
    loop = AnimationController(vsync: this, duration: loopDuration);
    tap = AnimationController(vsync: this, duration: tapDuration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = introReduceMotion(context);
    final changed = r != reduce;
    reduce = r;
    if (!_initialised) {
      _initialised = true;
      if (active) {
        start();
      } else if (reduce) {
        entrance.value = 1;
      }
      return;
    }
    if (changed) {
      if (reduce) {
        entrance.value = 1;
        loop.stop();
        tap.stop();
      } else if (active) {
        start();
      }
    }
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    final was = activeOf(oldWidget);
    if (!was && active) start();
    if (was && !active) stop();
  }

  void start() {
    if (reduce) {
      entrance.value = 1;
      loop.stop();
    } else {
      if (entrance.value < 1) entrance.forward(from: 0);
      loop.repeat();
    }
  }

  void stop() {
    entrance.stop();
    loop.stop();
    tap.stop();
    tap.value = 0;
    resetTaps();
  }

  void interacted({bool strong = false}) {
    if (strong) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    const IntroInteractionNotification().dispatch(context);
  }

  @override
  void dispose() {
    entrance.dispose();
    loop.dispose();
    tap.dispose();
    super.dispose();
  }
}

class _Parallax extends StatelessWidget {
  const _Parallax({required this.progress, required this.index, required this.factor, required this.enabled, required this.child});
  final ValueListenable<double> progress;
  final int index;
  final double factor;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return ValueListenableBuilder<double>(
      valueListenable: progress,
      child: child,
      builder: (context, _, c) => Transform.translate(
        offset: Offset(-introOffset(progress, index) * IntroSlideCanvas.size.width * factor, 0),
        child: c,
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.extent, required this.child});
  final double extent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: OverflowBox(
          minWidth: 0,
          minHeight: 0,
          maxWidth: extent,
          maxHeight: extent,
          child: child,
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.icon, required this.fill, required this.color});
  final IconData icon;
  final Color fill;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(shape: BoxShape.circle, color: fill, border: Border.all(color: Colors.white, width: 1.2)),
      child: Icon(icon, size: 12, color: color),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, required this.fill, required this.color, this.icon, this.size = 10, this.weight = FontWeight.w800});
  final String label;
  final Color fill;
  final Color color;
  final IconData? icon;
  final double size;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: color), const SizedBox(width: 4)],
          Text(label, maxLines: 1, softWrap: false, style: _ts(size, weight, color)),
        ],
      ),
    );
  }
}

// ============================================================
// Slide 3: Ask
// ============================================================

class IntroSlideAsk extends StatefulWidget {
  const IntroSlideAsk({super.key, required this.isActive, required this.progress});
  final bool isActive;
  final ValueListenable<double> progress;

  @override
  State<IntroSlideAsk> createState() => _AskState();
}

class _AskState extends _SlideState<IntroSlideAsk> {
  static const int _index = 2;
  final _accepted = ValueNotifier<bool>(false);

  static final _strikeOpacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 22),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 38),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
  ]);
  static final _strikeScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.0), weight: 22),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 38),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6), weight: 40),
  ]);
  static final _strikeRotation = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 60),
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.24), weight: 40),
  ]);

  @override
  Duration get entranceDuration => const Duration(milliseconds: 2600);
  @override
  Duration get loopDuration => const Duration(milliseconds: 2400);
  @override
  Duration get tapDuration => const Duration(milliseconds: 600);
  @override
  bool activeOf(IntroSlideAsk w) => w.isActive;
  @override
  ValueListenable<double> progressOf(IntroSlideAsk w) => w.progress;
  @override
  void resetTaps() => _accepted.value = false;

  @override
  void dispose() {
    _accepted.dispose();
    super.dispose();
  }

  void _onAccept() {
    if (_accepted.value || entrance.value < 0.75) return;
    interacted(strong: true);
    _accepted.value = true;
    if (!reduce) tap.forward(from: 0);
  }

  void _onReplay() {
    interacted();
    _accepted.value = false;
    tap.value = 0;
    if (!reduce) entrance.forward(from: 0.15);
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: SizedBox.fromSize(
        size: IntroSlideCanvas.size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 1,
              height: 28,
              child: _Parallax(progress: progress, index: _index, factor: 0.20, enabled: !reduce, child: _strikeRow()),
            ),
            Positioned(
              left: 16,
              top: 46,
              width: 248,
              height: 190,
              child: _Parallax(progress: progress, index: _index, factor: 0.55, enabled: !reduce, child: _chat()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _strikeRow() {
    final commission = _Chip(
      label: IntroStrings.commission,
      fill: Colors.white.withValues(alpha: 0.2),
      color: Colors.white,
      size: 11,
      weight: FontWeight.w700,
    );
    final noCommission = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.tick_circle, size: 12, color: AppColors.successDark),
          const SizedBox(width: 5),
          Text(IntroStrings.noCommission, maxLines: 1, softWrap: false, style: _ts(11, FontWeight.w800, AppColors.successDark)),
        ],
      ),
    );
    return AnimatedBuilder(
      animation: entrance,
      builder: (context, _) {
        final e = entrance.value;
        final s = _iv(e, 0.46, 0.88);
        final slash = _iv(s, 0.25, 0.5, Curves.easeOut);
        final u = _iv(e, 0.86, 1.0);
        final bounce = const ElasticOutCurve(0.6).transform(u);
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (s > 0 && s < 1)
              Opacity(
                opacity: _strikeOpacity.transform(s).clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: _strikeRotation.transform(s),
                  child: Transform.scale(
                    scale: _strikeScale.transform(s),
                    child: CustomPaint(
                      foregroundPainter: IntroSlashPainter(t: slash, color: AppColors.error),
                      child: commission,
                    ),
                  ),
                ),
              ),
            if (u > 0)
              Opacity(
                opacity: (u * 5).clamp(0.0, 1.0),
                child: Transform.scale(scale: bounce.clamp(0.0, 1.4), child: noCommission),
              ),
            if (u > 0 && u < 1)
              _Overlay(
                extent: 120,
                child: IntroSparkBurst(t: u, count: 8, radius: 46, colors: const [Colors.white, AppColors.tripLight]),
              ),
          ],
        );
      },
    );
  }

  Widget _chat() {
    final traveller = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onReplay,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: const BoxDecoration(
          color: AppColors.tripSurface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.message_text, size: 12, color: AppColors.tripDark),
            const SizedBox(width: 6),
            Text(IntroStrings.ask, maxLines: 1, softWrap: false, style: _ts(10.5, FontWeight.w700, AppColors.textDark)),
          ],
        ),
      ),
    );

    final hostAvatar = _bob(const _Avatar(icon: Iconsax.house_2, fill: AppColors.staySurface, color: AppColors.stay), 1);
    final driverAvatar = _bob(const _Avatar(icon: Iconsax.car, fill: AppColors.taxiSurface, color: AppColors.taxi), -1);

    final hostBubble = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        hostAvatar,
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _statusPill(),
              const SizedBox(height: 6),
              _acceptChip(),
            ],
          ),
        ),
      ],
    );

    final driverBubble = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        driverAvatar,
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
          ),
          child: Text(IntroStrings.fareSent, maxLines: 1, softWrap: false, style: _ts(10.5, FontWeight.w700, AppColors.textDark)),
        ),
      ],
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: 0,
          top: 0,
          child: AnimatedBuilder(
            animation: entrance,
            child: traveller,
            builder: (context, c) {
              final v = _iv(entrance.value, 0.19, 0.31, Curves.easeOutBack);
              return IgnorePointer(
                ignoring: v < 0.5,
                child: Opacity(
                  opacity: v.clamp(0.0, 1.0),
                  child: Transform.scale(scale: 0.7 + 0.3 * v, alignment: Alignment.centerRight, child: c),
                ),
              );
            },
          ),
        ),
        Positioned(left: 28, top: 48, child: _typing()),
        Positioned(
          left: 0,
          top: 44,
          child: _slideIn(hostBubble, 0.50, 0.62),
        ),
        Positioned(
          left: 0,
          top: 124,
          child: _slideIn(driverBubble, 0.73, 0.85),
        ),
      ],
    );
  }

  Widget _slideIn(Widget child, double a, double b) {
    return AnimatedBuilder(
      animation: entrance,
      child: child,
      builder: (context, c) {
        final v = _iv(entrance.value, a, b, Curves.easeOutCubic);
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(-24 * (1 - v), 0), child: c),
        );
      },
    );
  }

  Widget _bob(Widget child, double sign) {
    return AnimatedBuilder(
      animation: loop,
      child: child,
      builder: (context, c) => Transform.translate(
        offset: Offset(0, sign * 2 * math.sin(2 * math.pi * loop.value)),
        child: c,
      ),
    );
  }

  Widget _typing() {
    return AnimatedBuilder(
      animation: Listenable.merge([entrance, loop]),
      builder: (context, _) {
        final e = entrance.value;
        if (e < 0.31 || e >= 0.50) return const SizedBox(width: 44, height: 22);
        final fade = math.min(_iv(e, 0.31, 0.34), 1 - _iv(e, 0.47, 0.50));
        return Opacity(
          opacity: fade,
          child: Container(
            width: 44,
            height: 22,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(11)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Transform.translate(
                      offset: Offset(0, -4 * _dotBounce(loop.value, i)),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.9)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  double _dotBounce(double t, int i) {
    final s = (t * 4 - i * 0.2) % 1.0;
    return s < 0.5 ? math.sin(math.pi * s * 2) : 0;
  }

  Widget _statusPill() {
    return AnimatedBuilder(
      animation: entrance,
      builder: (context, _) {
        final e = entrance.value;
        final c = _iv(e, 0.65, 0.75);
        final tick = _iv(e, 0.65, 0.75, Curves.easeOutBack);
        final fill = Color.lerp(AppColors.neutralChip, AppColors.successSurface, c)!;
        final fg = Color.lerp(AppColors.neutralChipText, AppColors.successText, c)!;
        final offer = e >= 0.65;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(20)),
          child: AnimatedSwitcher(
            duration: reduce ? Duration.zero : const Duration(milliseconds: 250),
            child: offer
                ? Row(
                    key: const ValueKey('offer'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(scale: tick.clamp(0.0, 1.3), child: Icon(Iconsax.tick_circle, size: 11, color: fg)),
                      const SizedBox(width: 4),
                      Text(IntroStrings.offerReceived, maxLines: 1, softWrap: false, style: _ts(10, FontWeight.w700, fg)),
                    ],
                  )
                : Text(IntroStrings.sent, key: const ValueKey('sent'), maxLines: 1, softWrap: false, style: _ts(10, FontWeight.w700, fg)),
          ),
        );
      },
    );
  }

  Widget _acceptChip() {
    final chip = ValueListenableBuilder<bool>(
      valueListenable: _accepted,
      builder: (context, accepted, _) => AnimatedSwitcher(
        duration: reduce ? Duration.zero : const Duration(milliseconds: 260),
        transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: a, child: c)),
        child: accepted
            ? const _Chip(
                key: ValueKey('accepted'),
                label: IntroStrings.accepted,
                fill: AppColors.successSurface,
                color: AppColors.successText,
                icon: Iconsax.tick_circle,
              )
            : const _Chip(key: ValueKey('accept'), label: IntroStrings.accept, fill: AppColors.trip, color: Colors.white),
      ),
    );
    final tappable = GestureDetector(behavior: HitTestBehavior.opaque, onTap: _onAccept, child: chip);
    return AnimatedBuilder(
      animation: Listenable.merge([entrance, tap]),
      child: tappable,
      builder: (context, c) {
        final v = _iv(entrance.value, 0.75, 0.85);
        final t = tap.value;
        return IgnorePointer(
          ignoring: v < 0.5,
          child: Opacity(
            opacity: v,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                c!,
                if (t > 0 && t < 1)
                  _Overlay(
                    extent: 72,
                    child: IntroSparkBurst(
                      t: t,
                      count: 8,
                      radius: 28,
                      colors: const [AppColors.trip, AppColors.tripLight, AppColors.success],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================
// Slide 4: Live
// ============================================================

class IntroSlideLive extends StatefulWidget {
  const IntroSlideLive({super.key, required this.isActive, required this.progress});
  final bool isActive;
  final ValueListenable<double> progress;

  @override
  State<IntroSlideLive> createState() => _LiveState();
}

class _LiveState extends _SlideState<IntroSlideLive> {
  static const int _index = 3;
  static const int _tapDot = 1;
  static const int _tapShare = 2;
  static const double _rowH = 26;
  final _thirdDone = ValueNotifier<bool>(false);
  final _tapKind = ValueNotifier<int>(0);

  @override
  Duration get entranceDuration => const Duration(milliseconds: 1800);
  @override
  Duration get loopDuration => const Duration(milliseconds: 3000);
  @override
  Duration get tapDuration => const Duration(milliseconds: 500);
  @override
  bool activeOf(IntroSlideLive w) => w.isActive;
  @override
  ValueListenable<double> progressOf(IntroSlideLive w) => w.progress;
  @override
  void resetTaps() {
    _thirdDone.value = false;
    _tapKind.value = 0;
  }

  @override
  void dispose() {
    _thirdDone.dispose();
    _tapKind.dispose();
    super.dispose();
  }

  void _onThirdDot() {
    interacted();
    _thirdDone.value = !_thirdDone.value;
    if (_thirdDone.value && !reduce) {
      _tapKind.value = _tapDot;
      tap.forward(from: 0);
    } else {
      _tapKind.value = 0;
      tap.value = 0;
    }
  }

  void _onShare() {
    interacted();
    if (reduce) return;
    _tapKind.value = _tapShare;
    tap.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: SizedBox.fromSize(
        size: IntroSlideCanvas.size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: _Parallax(
                progress: progress,
                index: _index,
                factor: 0.10,
                enabled: !reduce,
                child: const CustomPaint(painter: _WatermarkPainter()),
              ),
            ),
            Positioned(
              left: 24,
              top: 6,
              width: 232,
              child: _Parallax(progress: progress, index: _index, factor: 0.45, enabled: !reduce, child: _card()),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 176,
              height: 32,
              child: _Parallax(progress: progress, index: _index, factor: 0.60, enabled: !reduce, child: Center(child: _share())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card() {
    final sun = AnimatedBuilder(
      animation: loop,
      child: const Icon(Iconsax.sun_1, size: 14, color: AppColors.gold),
      builder: (context, c) => Transform.scale(scale: 1 + 0.08 * math.sin(math.pi * loop.value), child: c),
    );
    final card = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              sun,
              const SizedBox(width: 6),
              Flexible(
                child: Text(IntroStrings.todayTitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: _ts(12, FontWeight.w800, AppColors.textDark)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: ValueListenableBuilder<bool>(
              valueListenable: _thirdDone,
              builder: (context, done, _) => Text(
                done ? IntroStrings.todayDone : IntroStrings.todayProgress,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _ts(9.5, FontWeight.w500, AppColors.textLight),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(height: _rowH * 3, child: _timeline()),
        ],
      ),
    );
    return AnimatedBuilder(
      animation: entrance,
      child: card,
      builder: (context, c) {
        final r = _iv(entrance.value, 0.0, 0.25, Curves.easeOutCubic);
        return Opacity(
          opacity: r,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - r)),
            child: Transform.scale(scale: 0.92 + 0.08 * r, child: c),
          ),
        );
      },
    );
  }

  Widget _timeline() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 9,
          top: _rowH / 2,
          width: 2,
          height: _rowH * 2,
          child: AnimatedBuilder(
            animation: entrance,
            builder: (context, _) => Align(
              alignment: Alignment.topCenter,
              child: FractionallySizedBox(
                heightFactor: _iv(entrance.value, 0.25, 0.61, Curves.easeInOut),
                widthFactor: 1,
                child: const ColoredBox(color: AppColors.divider),
              ),
            ),
          ),
        ),
        for (var i = 0; i < 3; i++)
          Positioned(
            left: 0,
            right: 0,
            top: _rowH * i,
            height: _rowH,
            child: Row(
              children: [
                SizedBox(width: 20, height: _rowH, child: i < 2 ? _entranceDot(i) : _thirdDot()),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(IntroStrings.todayRows[i],
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: _ts(10, FontWeight.w600, AppColors.textDark)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _entranceDot(int i) {
    return AnimatedBuilder(
      animation: entrance,
      builder: (context, _) {
        final a = i == 0 ? 0.39 : 0.53;
        return Center(child: _TimelineDot(tick: _iv(entrance.value, a, a + 0.12, Curves.easeOutBack)));
      },
    );
  }

  Widget _thirdDot() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onThirdDot,
      child: AnimatedBuilder(
        animation: Listenable.merge([entrance, loop, tap, _thirdDone, _tapKind]),
        builder: (context, _) {
          final done = _thirdDone.value;
          final animating = _tapKind.value == _tapDot && !reduce;
          final tick = !done ? 0.0 : (animating ? Curves.easeOutBack.transform(tap.value) : 1.0);
          final ping = !done && !reduce && loop.isAnimating && entrance.value >= 0.61;
          final t = loop.value;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (ping) ...[
                _Overlay(extent: 32, child: IntroPingRing(phase: t, baseSize: 12, maxScale: 2.6, color: AppColors.taxi)),
                _Overlay(
                  extent: 32,
                  child: IntroPingRing(phase: (t + 0.5) % 1.0, baseSize: 12, maxScale: 2.6, color: AppColors.taxi),
                ),
              ],
              _TimelineDot(tick: tick),
              if (animating && tap.value > 0 && tap.value < 1)
                _Overlay(
                  extent: 48,
                  child: IntroSparkBurst(t: tap.value, count: 6, radius: 18, colors: const [AppColors.taxi, AppColors.gold]),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _share() {
    final chip = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onShare,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.share, size: 12, color: Colors.white),
            const SizedBox(width: 6),
            Text(IntroStrings.shareSummary, maxLines: 1, softWrap: false, style: _ts(10.5, FontWeight.w700, Colors.white)),
          ],
        ),
      ),
    );
    return AnimatedBuilder(
      animation: Listenable.merge([entrance, tap, _tapKind]),
      child: chip,
      builder: (context, c) {
        final e = entrance.value;
        final v = _iv(e, 0.72, 0.85);
        final fly = _tapKind.value == _tapShare
            ? Curves.easeOutCubic.transform(tap.value)
            : _iv(e, 0.78, 1.0, Curves.easeOutCubic);
        return IgnorePointer(
          ignoring: v < 0.5,
          child: Opacity(
            opacity: v,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                c!,
                if (fly > 0 && fly < 1)
                  Positioned(
                    right: 8,
                    top: 6,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: math.sin(math.pi * fly).clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(22 * fly, -22 * fly),
                          child: const Icon(Iconsax.document_text, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({required this.tick});
  final double tick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 12,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: AppColors.taxi, width: 2),
            ),
          ),
          if (tick > 0)
            Transform.scale(
              scale: tick.clamp(0.0, 1.3),
              child: Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.taxi),
                child: const Icon(Icons.check_rounded, size: 9, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  const _WatermarkPainter();

  static Path? _cache;
  static Size? _cacheSize;

  static Path _path(Size size) {
    final cached = _cache;
    if (cached != null && _cacheSize == size) return cached;
    final raw = introRoutePath(IntroSlideCanvas.size);
    final b = raw.getBounds();
    Path out = raw;
    if (b.width > 0 && b.height > 0) {
      final target = Rect.fromLTWH(14, 30, size.width - 28, size.height - 60);
      final sx = target.width / b.width;
      final sy = target.height / b.height;
      final m = Float64List.fromList([
        sx, 0, 0, 0,
        0, sy, 0, 0,
        0, 0, 1, 0,
        target.left - b.left * sx, target.top - b.top * sy, 0, 1,
      ]);
      out = raw.transform(m);
    }
    _cache = out;
    _cacheSize = size;
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawPath(
      _path(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.10),
    );
  }

  @override
  bool shouldRepaint(covariant _WatermarkPainter oldDelegate) => false;
}

// ============================================================
// Slide 5: Start (finale)
// ============================================================

class IntroSlideStart extends StatefulWidget {
  const IntroSlideStart({super.key, required this.isActive, required this.progress});
  final bool isActive;
  final ValueListenable<double> progress;

  @override
  State<IntroSlideStart> createState() => _StartState();
}

class _StartState extends _SlideState<IntroSlideStart> {
  static const int _index = 4;
  static const Offset _centre = Offset(140, 104);
  static const double _ring = 78;
  static const List<double> _restDeg = [-135, -45, 45, 135];
  static const List<IconData> _icons = [Iconsax.location, Iconsax.routing_2, Iconsax.message_text, Iconsax.sun_1];
  static const List<Color> _iconColors = [AppColors.primary, AppColors.trip, AppColors.stay, AppColors.taxi];

  @override
  Duration get entranceDuration => const Duration(milliseconds: 1500);
  @override
  Duration get loopDuration => const Duration(milliseconds: 16000);
  @override
  Duration get tapDuration => const Duration(milliseconds: 900);
  @override
  bool activeOf(IntroSlideStart w) => w.isActive;
  @override
  ValueListenable<double> progressOf(IntroSlideStart w) => w.progress;
  @override
  void resetTaps() {}

  void _onMedallion() {
    interacted();
    if (!reduce) tap.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final medallion = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onMedallion,
      child: Container(
        width: 120,
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Image.asset('assets/images/app_logo.png', width: 44, height: 44, cacheWidth: 132),
        ),
      ),
    );

    final badges = [
      for (var k = 0; k < 4; k++)
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Icon(_icons[k], size: 15, color: _iconColors[k]),
        ),
    ];

    final ownerLine = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.house_2, size: 11, color: Colors.white70),
          const SizedBox(width: 5),
          Text(IntroStrings.ownerLine,
              maxLines: 1, softWrap: false, style: _ts(10.5, FontWeight.w600, Colors.white.withValues(alpha: 0.75))),
        ],
      ),
    );

    return MediaQuery.withNoTextScaling(
      child: SizedBox.fromSize(
        size: IntroSlideCanvas.size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: _Parallax(
                progress: progress,
                index: _index,
                factor: 0.15,
                enabled: !reduce,
                child: CustomPaint(painter: _RidgePainter(entrance)),
              ),
            ),
            Positioned.fill(
              child: _Parallax(
                progress: progress,
                index: _index,
                factor: 0.30,
                enabled: !reduce,
                child: AnimatedBuilder(
                  animation: Listenable.merge([entrance, loop, tap]),
                  child: medallion,
                  builder: (context, c) => _orbit(c!, badges),
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              top: 212,
              height: 20,
              child: AnimatedBuilder(
                animation: entrance,
                child: Center(child: ownerLine),
                builder: (context, c) => Opacity(opacity: _iv(entrance.value, 0.80, 1.0), child: c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orbit(Widget medallion, List<Widget> badges) {
    final e = entrance.value;
    final m = _iv(e, 0.0, 0.47, const ElasticOutCurve(0.7));
    final extra = tap.isAnimating ? Curves.easeOutCubic.transform(tap.value) : 0.0;
    final rot = (loop.value + extra) * 2 * math.pi;
    final spark = tap.isAnimating ? tap.value : _iv(e, 0.73, 1.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: _centre.dx - 60,
          top: _centre.dy - 60,
          width: 120,
          height: 120,
          child: Opacity(
            opacity: (e / 0.1).clamp(0.0, 1.0),
            child: Transform.scale(scale: (0.6 + 0.4 * m).clamp(0.0, 1.3), child: medallion),
          ),
        ),
        for (var k = 0; k < 4; k++) _badge(k, e, rot, badges[k]),
        if (spark > 0 && spark < 1)
          Positioned(
            left: _centre.dx - 70,
            top: _centre.dy - 70,
            width: 140,
            height: 140,
            child: IgnorePointer(
              child: Center(
                child: IntroSparkBurst(t: spark, count: 8, radius: 70, colors: const [Colors.white, AppColors.tripLight]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _badge(int k, double e, double rot, Widget badge) {
    final a = 0.40 + 0.06 * k;
    final u = _iv(e, a, a + 0.30, Curves.easeOutBack);
    final r = _ring * (1.8 - 0.8 * u);
    final angle = _restDeg[k] * math.pi / 180 + rot;
    final cx = _centre.dx + r * math.cos(angle);
    final cy = _centre.dy + r * math.sin(angle);
    return Positioned(
      left: cx - 15,
      top: cy - 15,
      width: 30,
      height: 30,
      child: IgnorePointer(child: Opacity(opacity: u.clamp(0.0, 1.0), child: badge)),
    );
  }
}

class _RidgePainter extends CustomPainter {
  _RidgePainter(this.anim) : super(repaint: anim);
  final Animation<double> anim;

  static Path? _back;
  static Path? _front;
  static Size? _cacheSize;

  static void _build(Size s) {
    if (_cacheSize == s && _back != null) return;
    final w = s.width, h = s.height;
    _back = Path()
      ..moveTo(0, h)
      ..lineTo(0, h - 44)
      ..quadraticBezierTo(w * 0.18, h - 74, w * 0.36, h - 50)
      ..quadraticBezierTo(w * 0.55, h - 28, w * 0.72, h - 60)
      ..quadraticBezierTo(w * 0.88, h - 82, w, h - 52)
      ..lineTo(w, h)
      ..close();
    _front = Path()
      ..moveTo(0, h)
      ..lineTo(0, h - 22)
      ..quadraticBezierTo(w * 0.25, h - 48, w * 0.5, h - 26)
      ..quadraticBezierTo(w * 0.75, h - 6, w, h - 34)
      ..lineTo(w, h)
      ..close();
    _cacheSize = s;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final r = _iv(anim.value, 0.0, 0.4, Curves.easeOutCubic);
    if (r <= 0) return;
    _build(size);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(0, 20 * (1 - r));
    canvas.drawPath(_back!, Paint()..color = Colors.white.withValues(alpha: 0.10 * r));
    canvas.drawPath(_front!, Paint()..color = Colors.white.withValues(alpha: 0.16 * r));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RidgePainter oldDelegate) => oldDelegate.anim != anim;
}
