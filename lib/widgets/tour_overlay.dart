import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_colors.dart';
import '../config/tour_registry.dart';
import '../utils/tour_target_ready.dart';

/// Paints a dark scrim over the whole screen with a spotlight cutout (visual
/// only, via BlendMode.clear — the barrier above still absorbs every touch)
/// around [targetRect]. [pulse] drives a breathing accent-colored ring around
/// the cutout — passed via `repaint` so this repaints every tick without the
/// owning widget rebuilding.
class _SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final double radius;
  final Animation<double> pulse;

  _SpotlightPainter({
    required this.targetRect,
    required this.radius,
    required this.pulse,
  }) : super(repaint: pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final fullScreen = Offset.zero & size;
    canvas.saveLayer(fullScreen, Paint());
    canvas.drawRect(fullScreen, Paint()..color = const Color(0xCC0A0F1E));
    final rrect = RRect.fromRectAndRadius(targetRect, Radius.circular(radius));
    canvas.drawRRect(rrect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // Breathing accent ring, drawn beneath the static white ring (matches
    // the mock's box-shadow stacking). t=0 is the ring's resting state, which
    // is also what's shown when reduced-motion is on and the controller
    // never starts (parked at its initial value 0.0).
    final t = Curves.easeInOut.transform(pulse.value);
    final ringWidth = 8.0 + (11.0 - 8.0) * t;
    final ringOpacity = 0.55 + (0.30 - 0.55) * t;
    final ringRRect = RRect.fromRectAndRadius(
      targetRect.inflate(ringWidth / 2),
      Radius.circular(radius),
    );
    canvas.drawRRect(
      ringRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..color = AppColors.accent.withValues(alpha: ringOpacity),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.targetRect != targetRect || oldDelegate.radius != radius;
}

/// Full-screen coach-mark overlay for one [TourStep] — spotlight + tooltip
/// card with Next/Skip. Rebuilt by TourController's Obx on every step change;
/// re-measures the target's current position on every build (so device
/// rotation/resize self-corrects without extra plumbing).
///
/// Stateful only for the spotlight's breathing pulse animation — the
/// controller is NOT tied to [step]/[index] in didUpdateWidget, so it
/// survives untouched across step-to-step transitions of the same tour
/// (TourHost's Obx only remounts this widget when currentTourStep flips
/// to/from null, i.e. at tour start/end, not between steps).
class TourOverlay extends StatefulWidget {
  final TourStep step;
  final int index;
  final int total;
  final String tourLabel;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const TourOverlay({
    super.key,
    required this.step,
    required this.index,
    required this.total,
    required this.tourLabel,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _pulseDecided = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      // Full breathe cycle (base -> peak -> base) is 1.8s with peak at the
      // midpoint — repeat(reverse:true) on a 900ms controller runs 900ms
      // forward + 900ms reverse = 1800ms per cycle, exactly that shape.
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Mirrors pulse_once.dart's own reduced-motion convention. If disabled,
    // the controller is simply never started — parked at its initial value
    // 0.0, which _SpotlightPainter reads as the ring's static base state.
    if (!_pulseDecided) {
      _pulseDecided = true;
      if (!MediaQuery.of(context).disableAnimations) {
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isTourTargetReady(widget.step.key)) return const SizedBox.shrink();
    final renderBox = widget.step.key.currentContext!.findRenderObject() as RenderBox;
    final targetRect =
        (renderBox.localToGlobal(Offset.zero) & renderBox.size).inflate(8);
    final screenSize = MediaQuery.of(context).size;
    final viewPadding = MediaQuery.of(context).viewPadding;
    final isLast = widget.index == widget.total - 1;
    // Picks whichever side genuinely has more room, not a fixed screen-height
    // split — a target sitting anywhere past the halfway point can still have
    // less real space below it than above (e.g. a rail further down a scrolled
    // list), and forcing the card below in that case pushed it off the bottom
    // edge, clipping Skip/Next entirely. Safe-area insets are excluded from
    // both sides since neither is usable space for the card either way.
    final spaceAbove = targetRect.top - viewPadding.top;
    final spaceBelow = screenSize.height - viewPadding.bottom - targetRect.bottom;
    final showBelow = spaceBelow >= spaceAbove;

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Lets the spotlighted target itself act like Next — matches the
        // pattern users expect from other apps' coach-marks. globalPosition
        // is already in the same coordinate space targetRect was built in
        // (renderBox.localToGlobal above), so no extra conversion is needed.
        // Taps on _TourCard's own Skip/Next never reach here — they're
        // nested descendants with their own recognizers, which the gesture
        // arena already resolves in their favor (this barrier's onTap was a
        // no-op throughout this session's testing while those buttons kept
        // working, direct proof of that precedence). Taps on the scrim
        // outside targetRect remain a no-op, same as before.
        onTapUp: (details) {
          if (targetRect.contains(details.globalPosition)) {
            HapticFeedback.selectionClick();
            widget.onNext();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _SpotlightPainter(
                  targetRect: targetRect,
                  radius: 14,
                  pulse: _pulseController,
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              top: showBelow ? targetRect.bottom + 16 : null,
              bottom: showBelow
                  ? null
                  : (screenSize.height - targetRect.top + 16),
              child: _TourCard(
                step: widget.step,
                index: widget.index,
                total: widget.total,
                tourLabel: widget.tourLabel,
                isLast: isLast,
                onNext: widget.onNext,
                onSkip: widget.onSkip,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  final TourStep step;
  final int index;
  final int total;
  final String tourLabel;
  final bool isLast;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _TourCard({
    required this.step,
    required this.index,
    required this.total,
    required this.tourLabel,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(step.icon, size: 13, color: AppColors.accent),
              const SizedBox(width: 5),
              Text(
                '${tourLabel.toUpperCase()} · ${index + 1} OF $total',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            step.title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            step.body,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textMedium,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          // Dots and actions are deliberately on separate rows, not squeezed
          // side by side — on a narrow device, 5 dots + "Skip" + a padded
          // "Finish" pill together don't fit one line and the action button
          // gets pushed past the screen edge (invisible, not just clipped).
          Row(
            children: List.generate(total, (i) {
              final active = i == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 4),
                width: active ? 14 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: active ? null : AppColors.divider,
                  gradient: active ? AppColors.primaryGradient : null,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onSkip,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHint,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Container (not Ink) for the gradient — a Container's own
              // decoration always paints in its own render pass, no
              // dependency on any ancestor Material being found for ink
              // features to draw into. A local, explicit
              // Material(color: transparent) wraps just the InkWell so the
              // ripple has its own guaranteed-adjacent host instead of
              // relying on a distant ancestor. ElevatedButton itself was
              // never an option here: its backgroundColor only accepts a
              // solid Color, not a Gradient.
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onNext,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        child: Text(
                          isLast ? 'Finish' : 'Next',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
