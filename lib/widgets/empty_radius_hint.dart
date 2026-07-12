import 'package:flutter/material.dart';
import '../config/app_colors.dart';

// Shown attached to the TOP edge of the radius circle when the current radius+filter
// combination has zero matching listings — a small tagged chip with a tail pointing
// down onto the circle's boundary, keeping the circle's own center (where the user's
// location pin sits) completely uncluttered. Positioning is the caller's job (see
// explore_screen.dart/explore_plots_screen.dart): this widget renders anchored at its
// own bottom-center, i.e. the tail tip, so the caller can place that tip exactly on the
// circle's edge. Purely informational — the radius circle itself keeps its normal color
// in every state; this is the only thing that changes.
class EmptyRadiusHint extends StatefulWidget {
  final String label;
  // On-screen pixel radius of the radius circle currently drawn on the map — the chip
  // scales down against this as the user zooms out, so it never spills outside the
  // (shrinking) circle the way a fixed-size chip does.
  final double circleRadiusPx;
  const EmptyRadiusHint({super.key, required this.label, required this.circleRadiusPx});

  @override
  State<EmptyRadiusHint> createState() => _EmptyRadiusHintState();
}

class _EmptyRadiusHintState extends State<EmptyRadiusHint> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 100px is roughly the on-screen circle radius the original fixed sizing was tuned
    // against — below that, shrink proportionally so zooming out never pushes the chip
    // outside the (now-smaller) circle. Capped at 1.0 rather than growing further when
    // zoomed in — the original design already looks right there.
    final scale = (widget.circleRadiusPx / 100).clamp(0.6, 1.0);
    return ScaleTransition(
      scale: _scale,
      // Pivot from the tail tip (the point anchored to the circle's edge) rather than
      // the chip's own center, so the pulse doesn't visibly drift off the boundary.
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12 * scale, vertical: 7 * scale),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withValues(alpha: 0.22), blurRadius: 12, offset: const Offset(0, 3)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off_rounded, size: 14 * scale, color: AppColors.warning),
                SizedBox(width: 6 * scale),
                Text(
                  widget.label,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11 * scale, fontWeight: FontWeight.w600, color: AppColors.textMedium),
                ),
              ],
            ),
          ),
          // Tail — pulled up to overlap the chip's rounded bottom edge so it reads as
          // one connected speech-bubble shape instead of a separate floating square.
          Transform.translate(
            offset: Offset(0, -5 * scale),
            child: Transform.rotate(
              angle: 0.7854, // 45°
              child: Container(width: 9 * scale, height: 9 * scale, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
