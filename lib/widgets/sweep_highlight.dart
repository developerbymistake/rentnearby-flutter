import 'package:flutter/material.dart';

/// Diagonal translucent highlight sweeping across [child] on loop.
class SweepHighlight extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final Duration duration;

  const SweepHighlight({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.duration = const Duration(milliseconds: 2800),
  });

  @override
  State<SweepHighlight> createState() => _SweepHighlightState();
}

class _SweepHighlightState extends State<SweepHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => Align(
                    alignment: Alignment(-3 + _controller.value * 6, 0),
                    child: Transform.rotate(
                      angle: -0.35,
                      child: Container(
                        width: 16,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.45),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
