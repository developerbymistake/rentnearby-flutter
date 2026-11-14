import 'package:flutter/material.dart';
import '../design/extra/motion_kit.dart';

class RevealBarController {
  final shown = ValueNotifier<bool>(false);
  final height = ValueNotifier<double>(0);
  ScrollController? _scroll;

  void attach(ScrollController scroll) {
    _scroll = scroll;
    scroll.addListener(evaluate);
  }

  void evaluate() {
    final s = _scroll;
    if (s == null || !s.hasClients || !s.position.hasContentDimensions) return;
    final p = s.position;
    final fits = p.maxScrollExtent <= height.value + 1;
    shown.value = fits || p.pixels >= p.maxScrollExtent - 8;
  }

  Widget wrap(Widget scrollView) => NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) {
          evaluate();
          return false;
        },
        child: scrollView,
      );

  void dispose() {
    _scroll?.removeListener(evaluate);
    shown.dispose();
    height.dispose();
  }
}

class RevealBarPad extends StatelessWidget {
  const RevealBarPad(this.controller, {super.key});

  final RevealBarController controller;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
        child: ValueListenableBuilder<double>(
          valueListenable: controller.height,
          builder: (_, h, _) => SizedBox(height: h),
        ),
      );
}

class ScrollRevealBar extends StatefulWidget {
  const ScrollRevealBar({super.key, required this.controller, required this.child});

  final RevealBarController controller;
  final Widget child;

  @override
  State<ScrollRevealBar> createState() => _ScrollRevealBarState();
}

class _ScrollRevealBarState extends State<ScrollRevealBar> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this);
  late final Animation<double> _in = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
  final _key = GlobalKey();

  RevealBarController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.shown.addListener(_sync);
    _measureLater();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = KitMotion.reduce(context);
    _anim.duration = reduce ? Duration.zero : const Duration(milliseconds: 380);
    _anim.reverseDuration = reduce ? Duration.zero : const Duration(milliseconds: 300);
  }

  @override
  void dispose() {
    _c.shown.removeListener(_sync);
    _anim.dispose();
    super.dispose();
  }

  void _sync() => _c.shown.value ? _anim.forward() : _anim.reverse();

  void _measureLater() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      if ((box.size.height - _c.height.value).abs() > 0.5) {
        _c.height.value = box.size.height;
        _c.evaluate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _measureLater();
    return AnimatedBuilder(
      animation: _anim,
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          _measureLater();
          return false;
        },
        child: SizeChangedLayoutNotifier(child: KeyedSubtree(key: _key, child: widget.child)),
      ),
      builder: (context, child) => Offstage(
        offstage: _anim.isDismissed,
        child: IgnorePointer(
          ignoring: !_c.shown.value,
          child: FadeTransition(
            opacity: _in,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(_in),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
