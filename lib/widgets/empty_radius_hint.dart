import 'package:flutter/material.dart';
import '../config/app_colors.dart';

// Centered on the map when the current radius+filter combination has zero matching
// listings. Purely informational — the radius circle itself keeps its normal color in
// every state; this is the only thing that changes.
class EmptyRadiusHint extends StatefulWidget {
  final String label;
  // On-screen pixel radius of the radius circle currently drawn on the map — the hint
  // scales down against this as the user zooms out, so it never spills outside the
  // (shrinking) circle the way a fixed-size hint does.
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
    // 100px is roughly the on-screen circle radius the original fixed sizing (40px
    // badge, 13px label) reads well against — below that, shrink proportionally so
    // zooming out never pushes the hint outside the (now-smaller) circle. Capped at 1.0
    // rather than growing further when zoomed in — the original design already looks
    // right there. Text gets a gentler floor than the icon badge so the label stays
    // legible even at the smallest sizes.
    final iconScale = (widget.circleRadiusPx / 100).clamp(0.45, 1.0);
    final textScale = (widget.circleRadiusPx / 100).clamp(0.75, 1.0);
    final badgeSize = 40.0 * iconScale;
    return ScaleTransition(
      scale: _scale,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: badgeSize, height: badgeSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.warning.withValues(alpha: 0.14),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: Icon(Icons.search_off_rounded, size: 20 * iconScale, color: AppColors.warning),
        ),
        SizedBox(height: 8 * iconScale),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12 * textScale, vertical: 7 * textScale),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Text(
            widget.label,
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13 * textScale, fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
        ),
      ]),
    );
  }
}
