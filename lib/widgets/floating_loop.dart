import 'package:flutter/material.dart';

/// Continuous gentle up/down float on [child].
class FloatingLoop extends StatefulWidget {
  final Widget child;
  final double distance;
  final Duration duration;

  const FloatingLoop({
    super.key,
    required this.child,
    this.distance = 7,
    this.duration = const Duration(milliseconds: 1700),
  });

  @override
  State<FloatingLoop> createState() => _FloatingLoopState();
}

class _FloatingLoopState extends State<FloatingLoop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(
            0,
            -widget.distance * Curves.easeInOut.transform(_controller.value),
          ),
          child: child,
        ),
      ),
    );
  }
}
