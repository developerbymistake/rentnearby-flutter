import 'dart:math' as math;

import 'package:flutter/material.dart';

enum IconMotionStyle { pulse, scan, grow }

/// Loops a small distinct motion on [child] per [style].
class IconMotion extends StatefulWidget {
  final Widget child;
  final IconMotionStyle style;
  final Duration duration;

  const IconMotion({
    super.key,
    required this.child,
    required this.style,
    this.duration = const Duration(milliseconds: 1800),
  });

  @override
  State<IconMotion> createState() => _IconMotionState();
}

class _IconMotionState extends State<IconMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (widget.style == IconMotionStyle.scan) {
      _controller.repeat();
    } else {
      _controller.repeat(reverse: true);
    }
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
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_controller.value);
          switch (widget.style) {
            case IconMotionStyle.pulse:
              return Transform.scale(scale: 1 + t * 0.22, child: child);
            case IconMotionStyle.scan:
              final angle = _controller.value * 2 * math.pi;
              return Transform.translate(
                offset: Offset(math.cos(angle), math.sin(angle)) * 2.4,
                child: child,
              );
            case IconMotionStyle.grow:
              return Transform.scale(
                scale: 1 + t * 0.22,
                alignment: Alignment.bottomCenter,
                child: child,
              );
          }
        },
      ),
    );
  }
}
