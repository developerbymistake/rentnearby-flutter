import 'package:flutter/material.dart';
import '../config/app_colors.dart';

// Centered on the map when the current radius+filter combination has zero matching
// listings. Purely informational — the radius circle itself keeps its normal color in
// every state; this is the only thing that changes.
class EmptyRadiusHint extends StatefulWidget {
  final String label;
  const EmptyRadiusHint({super.key, required this.label});

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
    return ScaleTransition(
      scale: _scale,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.warning.withValues(alpha: 0.14),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: const Icon(Icons.search_off_rounded, size: 20, color: AppColors.warning),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Text(
            widget.label,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
          ),
        ),
      ]),
    );
  }
}
