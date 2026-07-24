import 'package:flutter/material.dart';

/// Wraps [child] in a short zoom-in/zoom-out pulse (a few times), then settles
/// back to rest. Used to draw attention to a call-to-action (e.g. "Make it
/// Live") when the screen first appears, without animating forever.
/// Respects the platform's reduce-motion setting.
class PulseOnce extends StatefulWidget {
  final Widget child;
  final int pulseCount;
  final bool paused;

  const PulseOnce({super.key, required this.child, this.pulseCount = 3, this.paused = false});

  @override
  State<PulseOnce> createState() => _PulseOnceState();
}

class _PulseOnceState extends State<PulseOnce> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.08).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
    ]).animate(_controller);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !widget.paused && !MediaQuery.of(context).disableAnimations) {
      _started = true;
      _runPulses();
    }
  }

  @override
  void didUpdateWidget(PulseOnce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paused && !widget.paused && !_started && !MediaQuery.of(context).disableAnimations) {
      _started = true;
      _runPulses();
    }
  }

  Future<void> _runPulses() async {
    for (var i = 0; i < widget.pulseCount; i++) {
      if (!mounted || widget.paused) return;
      await _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
      child: widget.child,
    );
  }
}
