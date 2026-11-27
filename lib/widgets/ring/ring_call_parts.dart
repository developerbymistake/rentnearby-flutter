import 'dart:math' as math;

import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

import '../../config/app_colors.dart';

/// The call-style look shared by every ring screen (taxi request, stay enquiry).
abstract final class RingCallLook {
  static const Color acceptGreen = AppColors.ringAccept;
  static const Color onDark = Colors.white;
  static const double pillFont = 13;
  static final Color top = Color.lerp(ListingPalette.sunrise.g2, ListingPalette.coral.g1, 0.55)!;
  static final Color mid = Color.lerp(ListingPalette.coral.g1, ListingPalette.coral.g2, 0.35)!;
  static final Color bottom = ListingPalette.coral.g2;
}

/// Full-bleed gradient page; back always closes through [onClose].
class RingCallPage extends StatelessWidget {
  const RingCallPage({super.key, required this.onClose, required this.child});

  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onClose();
      },
      child: Scaffold(
        backgroundColor: RingCallLook.bottom,
        body: DecoratedBox(
          position: DecorationPosition.background,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [RingCallLook.top, RingCallLook.mid, RingCallLook.bottom],
              stops: const [0, 0.55, 1],
            ),
          ),
          child: SizedBox.expand(child: SafeArea(child: child)),
        ),
      ),
    );
  }
}

/// The ringing column: swipe up answers, the content scales down on short screens.
class RingCallLayout extends StatelessWidget {
  const RingCallLayout({super.key, required this.onSwipeUp, required this.child});

  final VoidCallback? onSwipeUp;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final swipe = onSwipeUp;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: swipe == null
          ? null
          : (d) {
              if ((d.primaryVelocity ?? 0) < -300) swipe();
            },
      child: LayoutBuilder(
        builder: (context, c) => FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: c.maxWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: IntrinsicHeight(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Art disc inside the countdown arc; only the arc repaints on a tick.
class RingCallDial extends StatelessWidget {
  const RingCallDial({super.key, required this.art, required this.progressOf, required this.ticks});

  final String art;
  final double Function() progressOf;
  final Listenable ticks;

  @override
  Widget build(BuildContext context) {
    final box = DS.s(230);
    final disc = DS.s(180);
    return SizedBox(
      width: box,
      height: box,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                key: const ValueKey('ring_progress'),
                painter: RingProgressPainter(
                  progressOf: progressOf,
                  repaint: ticks,
                  radius: DS.s(92),
                  stroke: DS.s(8),
                  pulseRadius: DS.s(139),
                  pulseStroke: DS.s(2),
                  ringShift: DS.s(15),
                ),
              ),
            ),
          ),
          RepaintBoundary(
            child: Container(
              width: disc,
              height: disc,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: Alpha.v14)),
              alignment: Alignment.center,
              child: Art3D(asset: art, size: 120, shadowOffset: const Offset(6, 9), shadowBlur: 8, shadowAlpha: Alpha.scrim),
            ),
          ),
        ],
      ),
    );
  }
}

/// Decline (red cross) and Accept (green phone) buttons of a ring screen.
class RingCallButtons extends StatelessWidget {
  const RingCallButtons({super.key, required this.declineLabel, required this.acceptLabel, required this.onDecline, required this.onAccept});

  final String declineLabel;
  final String acceptLabel;
  final VoidCallback? onDecline;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RingRoundButton(label: declineLabel, color: DesignColors.error, glyph: const RingDeclineGlyph(), onTap: onDecline),
        Gap.h(90),
        RingRoundButton(label: acceptLabel, color: RingCallLook.acceptGreen, glyph: Icon(Icons.call, color: Colors.white, size: DS.s(30)), onTap: onAccept),
      ],
    );
  }
}

class RingStateView extends StatelessWidget {
  const RingStateView({
    super.key,
    required this.eyebrow,
    this.art,
    this.spinner = false,
    required this.title,
    required this.sub,
    this.primary,
    this.onPrimary,
    this.secondary,
    this.onSecondary,
  });

  final String eyebrow;
  final String? art;
  final bool spinner;
  final String title;
  final String sub;
  final String? primary;
  final VoidCallback? onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final a = art;
    final disc = DS.s(112);
    final p = primary;
    final s = secondary;
    return Padding(
      padding: DS.insets(l: 18, r: 18, t: 40, b: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(eyebrow.toUpperCase(), textAlign: TextAlign.center, style: Ink3D.text(11, FontWeight.w500, Colors.white.withValues(alpha: Alpha.v80), letterSpacing: 0.6)),
                  Gap.v(36),
                  if (spinner)
                    SizedBox(
                      width: DS.s(88),
                      height: DS.s(88),
                      child: CircularProgressIndicator(
                        key: const ValueKey('ring_opening_spinner'),
                        strokeWidth: DS.s(4),
                        color: ListingPalette.sunrise.g1,
                        backgroundColor: Colors.white.withValues(alpha: Alpha.v18),
                      ),
                    )
                  else if (a != null)
                    Container(
                      width: disc,
                      height: disc,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: Alpha.v14)),
                      child: Art3D(asset: a, size: 72, shadowAlpha: Alpha.scrim),
                    ),
                  Gap.v(24),
                  Text(title, key: const ValueKey('ring_state_title'), textAlign: TextAlign.center, style: Ink3D.text(18, FontWeight.w700, Colors.white, height: 1.3)),
                  Gap.v(8),
                  Text(sub, key: const ValueKey('ring_state_sub'), textAlign: TextAlign.center, style: Ink3D.text(11.5, FontWeight.w500, Colors.white, height: 1.5)),
                ],
              ),
            ),
          ),
          if (p != null) GradientPillButton(key: const ValueKey('ring_state_primary'), tone: ListingTone.coral, label: p, onTap: onPrimary, height: 44, fontSize: RingCallLook.pillFont),
          if (s != null) ...[
            Gap.v(10),
            WhitePillButton(key: const ValueKey('ring_state_secondary'), tone: ListingTone.coral, label: s, onTap: onSecondary, height: 44, fontSize: RingCallLook.pillFont),
          ],
        ],
      ),
    );
  }
}

class RingProgressPainter extends CustomPainter {
  RingProgressPainter({
    required this.progressOf,
    required Listenable repaint,
    required this.radius,
    required this.stroke,
    required this.pulseRadius,
    required this.pulseStroke,
    required this.ringShift,
  }) : super(repaint: repaint);

  final double Function() progressOf;
  final double radius;
  final double stroke;
  final double pulseRadius;
  final double pulseStroke;
  final double ringShift;

  double get progress => progressOf();

  @override
  void paint(Canvas canvas, Size size) {
    final progress = this.progress;
    final c = size.center(Offset.zero);
    final rc = c - Offset(ringShift, ringShift);
    canvas.drawCircle(
      c,
      pulseRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = pulseStroke
        ..color = Colors.white.withValues(alpha: Alpha.v22),
    );
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(rc, radius, arc..color = Colors.white.withValues(alpha: Alpha.v18));
    if (progress <= 0) return;
    canvas.drawArc(Rect.fromCircle(center: rc, radius: radius), -math.pi / 2, 2 * math.pi * progress, false, arc..color = ListingPalette.sunrise.g1);
  }

  @override
  bool shouldRepaint(RingProgressPainter old) =>
      old.progressOf != progressOf || old.radius != radius || old.stroke != stroke || old.pulseRadius != pulseRadius || old.pulseStroke != pulseStroke || old.ringShift != ringShift;
}

class RingChip extends StatelessWidget {
  const RingChip(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: Alpha.v16),
        borderRadius: DS.circular(14),
      ),
      child: Padding(
        padding: DS.sym(h: 14, v: 6),
        child: Text(text, style: Ink3D.text(12.5, FontWeight.w600, Colors.white)),
      ),
    );
  }
}

class RingRoundButton extends StatelessWidget {
  const RingRoundButton({super.key, required this.label, required this.color, required this.glyph, required this.onTap});
  static const List<BoxShadow> _shadow = [BoxShadow(color: AppColors.ringButtonShadow, offset: Offset(0, 8), blurRadius: 18)];
  final String label;
  final Color color;
  final Widget glyph;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final size = DS.s(76);
    return Tap3D(
      onTap: onTap,
      label: label,
      exclude: true,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: DS.shadows(_shadow)),
              alignment: Alignment.center,
              child: glyph,
            ),
            Gap.v(10),
            Text(label, style: Ink3D.text(13, FontWeight.w600, Colors.white)),
          ],
        ),
      ),
    );
  }
}

class RingDeclineGlyph extends StatelessWidget {
  const RingDeclineGlyph({super.key});

  @override
  Widget build(BuildContext context) {
    final side = DS.s(30);
    return CustomPaint(key: const ValueKey('ring_decline_x'), size: Size.square(side), painter: _XPainter());
  }
}

class _XPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 3 / 24
      ..strokeCap = StrokeCap.round;
    final a = size.width * 0.25;
    final b = size.width * 0.75;
    canvas.drawLine(Offset(a, a), Offset(b, b), p);
    canvas.drawLine(Offset(b, a), Offset(a, b), p);
  }

  @override
  bool shouldRepaint(_XPainter old) => false;
}
