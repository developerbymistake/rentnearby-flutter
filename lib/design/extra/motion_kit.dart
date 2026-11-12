import 'dart:math' as math;
import 'package:bakhli/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

abstract final class KitMotion {
  static bool reduce(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static const int staggerStepMs = 60;
  static const int staggerItemMs = 350;
  static const int staggerCap = 8;
  static const int listItemMs = 400;
  static const int listStepMs = 50;
  static const int listDelayCap = 6;
  static const int railMs = 600;
  static const double railOffset = 60;

  static int staggerTotalMs(int count) =>
      staggerItemMs + staggerStepMs * math.min(math.max(count, 1), staggerCap);

  static Interval staggerInterval(int index, int count) {
    final total = staggerTotalMs(count);
    final i = math.min(index, staggerCap - 1);
    return Interval(
      staggerStepMs * i / total,
      math.min(1.0, (staggerStepMs * i + staggerItemMs) / total),
      curve: Curves.fastOutSlowIn,
    );
  }
}

class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.scale = 0.97,
    this.enabled = true,
  });

  final Widget child;
  final double scale;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 140),
  );
  late final Animation<double> _s = Tween<double>(begin: 1, end: widget.scale)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut, reverseCurve: Curves.easeOutBack));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent _) {
    if (widget.enabled && !KitMotion.reduce(context)) _c.forward();
  }

  void _up(PointerEvent _) => _c.reverse();

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: ScaleTransition(scale: _s, child: widget.child),
    );
  }
}

class EntranceOnce extends StatefulWidget {
  const EntranceOnce({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 30,
    this.dx = 0,
  });

  final Widget child;
  final int index;
  final double offset;
  final double dx;

  @override
  State<EntranceOnce> createState() => _EntranceOnceState();
}

class _EntranceOnceState extends State<EntranceOnce>
    with SingleTickerProviderStateMixin {
  late final int _delay =
      KitMotion.listStepMs * math.min(widget.index, KitMotion.listDelayCap);
  late final AnimationController _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: KitMotion.listItemMs + _delay));
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: Interval(_delay / (KitMotion.listItemMs + _delay), 1.0,
        curve: Curves.fastOutSlowIn),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (KitMotion.reduce(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(
          offset: Offset(widget.dx * (1 - _a.value), widget.offset * (1 - _a.value)),
          child: child,
        ),
      ),
    );
  }
}

class _StaggerScope extends InheritedWidget {
  const _StaggerScope(
      {required this.controller, required this.count, required super.child});

  final AnimationController controller;
  final int count;

  @override
  bool updateShouldNotify(_StaggerScope old) =>
      old.controller != controller || old.count != count;
}

class StaggerHost extends StatefulWidget {
  const StaggerHost({super.key, required this.count, required this.child, this.replay});

  final int count;
  final Widget child;
  final Listenable? replay;

  static StaggerHostState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<StaggerHostState>();

  @override
  State<StaggerHost> createState() => StaggerHostState();
}

class StaggerHostState extends State<StaggerHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: KitMotion.staggerTotalMs(widget.count)));
  bool _started = false;

  void replay() {
    if (!mounted) return;
    if (KitMotion.reduce(context)) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.replay?.addListener(replay);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (KitMotion.reduce(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void didUpdateWidget(StaggerHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replay != widget.replay) {
      oldWidget.replay?.removeListener(replay);
      widget.replay?.addListener(replay);
    }
    if (oldWidget.count != widget.count) {
      _c.duration = Duration(milliseconds: KitMotion.staggerTotalMs(widget.count));
    }
  }

  @override
  void dispose() {
    widget.replay?.removeListener(replay);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _StaggerScope(controller: _c, count: widget.count, child: widget.child);
}

class StaggerItem extends StatefulWidget {
  const StaggerItem({super.key, required this.index, required this.child, this.offset = 30});

  final int index;
  final double offset;
  final Widget child;

  @override
  State<StaggerItem> createState() => _StaggerItemState();
}

class _StaggerItemState extends State<StaggerItem> {
  CurvedAnimation? _a;
  _StaggerScope? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = context.dependOnInheritedWidgetOfExactType<_StaggerScope>();
    if (scope == null) {
      _a?.dispose();
      _a = null;
    } else if (_a == null || _scope?.controller != scope.controller || _scope?.count != scope.count) {
      _a?.dispose();
      _a = CurvedAnimation(parent: scope.controller, curve: KitMotion.staggerInterval(widget.index, scope.count));
    }
    _scope = scope;
  }

  @override
  void didUpdateWidget(StaggerItem old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index && _scope != null) {
      _a?.dispose();
      _a = CurvedAnimation(parent: _scope!.controller, curve: KitMotion.staggerInterval(widget.index, _scope!.count));
    }
  }

  @override
  void dispose() {
    _a?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    if (a == null) return widget.child;
    return AnimatedBuilder(
      animation: a,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: a.value,
        child: Transform.translate(offset: Offset(0, widget.offset * (1 - a.value)), child: child),
      ),
    );
  }
}

class StaggerColumn extends StatelessWidget {
  const StaggerColumn({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.replay,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;
  final Listenable? replay;

  @override
  Widget build(BuildContext context) {
    return StaggerHost(
      count: children.length,
      replay: replay,
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          for (var i = 0; i < children.length; i++)
            StaggerItem(index: i, child: children[i]),
        ],
      ),
    );
  }
}

class _TabScope extends InheritedWidget {
  const _TabScope({required this.tab, required super.child});
  final int tab;

  @override
  bool updateShouldNotify(_TabScope old) => old.tab != tab;
}

class TabEntrance extends StatefulWidget {
  const TabEntrance({super.key, required this.tab, required this.child, this.source});

  final int tab;
  final Widget child;
  final RxInt? source;

  static int? tabOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_TabScope>()?.tab;

  static bool isActive(BuildContext context) {
    final tab = tabOf(context);
    if (tab == null || !Get.isRegistered<AuthController>()) return true;
    return Get.find<AuthController>().tabIndex.value == tab;
  }

  @override
  State<TabEntrance> createState() => _TabEntranceState();
}

class _TabEntranceState extends State<TabEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 250), value: 1);
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.fastOutSlowIn);
  Worker? _worker;

  RxInt? get _src => widget.source ??
      (Get.isRegistered<AuthController>() ? Get.find<AuthController>().tabIndex : null);

  @override
  void initState() {
    super.initState();
    _worker = _src == null
        ? null
        : ever<int>(_src!, (i) {
            if (i == widget.tab && mounted && !KitMotion.reduce(context)) {
              _c.forward(from: 0);
            }
          });
  }

  @override
  void dispose() {
    _worker?.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TabScope(
      tab: widget.tab,
      child: AnimatedBuilder(
        animation: _a,
        child: widget.child,
        builder: (context, child) => Opacity(
          opacity: _a.value,
          child: Transform.translate(offset: Offset(0, 16 * (1 - _a.value)), child: child),
        ),
      ),
    );
  }
}

class FirstVisible extends StatefulWidget {
  const FirstVisible({super.key, required this.onVisible, required this.child});

  final VoidCallback onVisible;
  final Widget child;

  @override
  State<FirstVisible> createState() => _FirstVisibleState();
}

class _FirstVisibleState extends State<FirstVisible> {
  ScrollPosition? _pos;
  Worker? _worker;
  bool _fired = false;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<AuthController>()) {
      _worker = ever<int>(Get.find<AuthController>().tabIndex, (_) => _schedule());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != _pos) {
      _pos?.removeListener(_schedule);
      _pos = pos;
      _pos?.addListener(_schedule);
    }
    _schedule();
  }

  @override
  void didUpdateWidget(FirstVisible oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  @override
  void dispose() {
    _pos?.removeListener(_schedule);
    _worker?.dispose();
    super.dispose();
  }

  void _schedule() {
    if (_fired || _scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _fired) return;
      if (_visible()) {
        _fired = true;
        widget.onVisible();
      }
    });
  }

  bool _visible() {
    if (KitMotion.reduce(context)) return true;
    if (!TabEntrance.isActive(context)) return false;
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return false;
    final topLeft = ro.localToGlobal(Offset.zero);
    final size = MediaQuery.sizeOf(context);
    final rect = topLeft & ro.size;
    if (rect.width <= 0 || rect.height <= 0) return false;
    return rect.bottom > 0 && rect.top < size.height && rect.right > 0 && rect.left < size.width;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class RailReveal extends StatefulWidget {
  const RailReveal({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.separator = 12,
    this.physics,
    this.cellPadding = EdgeInsets.zero,
  });

  final EdgeInsets cellPadding;
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final EdgeInsets padding;
  final double separator;
  final ScrollPhysics? physics;

  @override
  State<RailReveal> createState() => _RailRevealState();
}

class _RailRevealState extends State<RailReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: KitMotion.railMs));
  bool _seen = false;

  void _go() {
    _seen = true;
    if (KitMotion.reduce(context)) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_seen && KitMotion.reduce(context)) _c.value = 1;
  }

  @override
  void didUpdateWidget(RailReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount && _seen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _go();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = math.max(1, math.min(widget.itemCount, 10));
    return FirstVisible(
      onVisible: _go,
      child: ListView.separated(
        padding: widget.padding,
        physics: widget.physics,
        scrollDirection: Axis.horizontal,
        itemCount: widget.itemCount,
        separatorBuilder: (_, _) => SizedBox(width: widget.separator),
        itemBuilder: (context, index) {
          final a = _c.drive(CurveTween(
              curve: Interval((1 / count) * math.min(index, count - 1) * 0.6, 1.0,
                  curve: Curves.fastOutSlowIn)));
          return AnimatedBuilder(
            animation: a,
            child: Padding(padding: widget.cellPadding, child: widget.itemBuilder(context, index)),
            builder: (context, child) => Opacity(
              opacity: a.value,
              child: Transform.translate(
                  offset: Offset(KitMotion.railOffset * (1 - a.value), 0),
                  child: child),
            ),
          );
        },
      ),
    );
  }
}

class KitSwitcher extends StatelessWidget {
  const KitSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.animateSize = false,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final Duration duration;
  final bool animateSize;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final d = KitMotion.reduce(context) ? Duration.zero : duration;
    Widget w = AnimatedSwitcher(
      duration: d,
      switchInCurve: Curves.fastOutSlowIn,
      switchOutCurve: Curves.fastOutSlowIn,
      layoutBuilder: (current, previous) => Stack(
        alignment: alignment,
        children: [...previous, ?current],
      ),
      child: child,
    );
    if (animateSize) {
      w = AnimatedSize(duration: d, curve: Curves.fastOutSlowIn, alignment: Alignment.topCenter, child: w);
    }
    return w;
  }
}

class SkeletonSwitcher extends StatelessWidget {
  const SkeletonSwitcher({
    super.key,
    required this.loading,
    required this.skeleton,
    required this.child,
  });

  final bool loading;
  final Widget skeleton;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return KitSwitcher(
      animateSize: true,
      child: loading
          ? KeyedSubtree(key: const ValueKey('kit_skeleton'), child: skeleton)
          : KeyedSubtree(key: const ValueKey('kit_content'), child: child),
    );
  }
}

class SelectionPop extends StatefulWidget {
  const SelectionPop({super.key, required this.selected, required this.child, this.peak = 1.06});

  final bool selected;
  final double peak;
  final Widget child;

  @override
  State<SelectionPop> createState() => _SelectionPopState();
}

class _SelectionPopState extends State<SelectionPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 250));

  @override
  void didUpdateWidget(SelectionPop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.selected && widget.selected && !KitMotion.reduce(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: widget.peak).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: widget.peak, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
    ]).animate(_c);
    return ScaleTransition(scale: s, child: widget.child);
  }
}

class KitRouteReveal extends StatefulWidget {
  const KitRouteReveal({super.key, required this.child, this.axis = Axis.horizontal});

  final Widget child;
  final Axis axis;

  @override
  State<KitRouteReveal> createState() => _KitRouteRevealState();
}

class _KitRouteRevealState extends State<KitRouteReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (KitMotion.reduce(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: _c, curve: Curves.fastOutSlowIn);
    return ClipRect(
      clipper: _RevealClipper(t, widget.axis),
      child: widget.child,
    );
  }
}

class _RevealClipper extends CustomClipper<Rect> {
  _RevealClipper(this.t, this.axis) : super(reclip: t);
  final Animation<double> t;
  final Axis axis;

  @override
  Rect getClip(Size size) => axis == Axis.horizontal
      ? Rect.fromLTWH(0, 0, size.width * t.value, size.height)
      : Rect.fromLTWH(0, 0, size.width, size.height * t.value);

  @override
  bool shouldReclip(_RevealClipper old) => old.t != t || old.axis != axis;
}
