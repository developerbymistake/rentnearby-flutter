import 'package:bakhli/design/design.dart';
import 'package:flutter/material.dart';

enum MapSpotCardEdge { top, bottom }

class MapSpotCardHost extends StatefulWidget {
  final Object? id;
  final Widget? child;
  final String? label;
  final MapSpotCardEdge edge;
  final VoidCallback onClose;

  static const Duration openDuration = Duration(milliseconds: 240);
  static const Duration closeDuration = Duration(milliseconds: 180);
  static const Duration switchDuration = Duration(milliseconds: 160);
  static const Duration snapDuration = Duration(milliseconds: 160);
  static const double slide = 12;
  static const double closeDistance = 40;
  static const double closeVelocity = 600;

  const MapSpotCardHost({
    super.key,
    required this.id,
    required this.child,
    required this.onClose,
    this.label,
    this.edge = MapSpotCardEdge.top,
  }) : assert((id == null) == (child == null));

  @override
  State<MapSpotCardHost> createState() => _MapSpotCardHostState();
}

class _MapSpotCardHostState extends State<MapSpotCardHost> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final CurvedAnimation _curve;

  Object? _id;
  Widget? _child;
  String? _label;
  double _drag = 0;
  bool _dragging = false;
  bool _reduce = false;

  double get _toEdge => widget.edge == MapSpotCardEdge.top ? -1 : 1;
  bool get _exiting => widget.child == null && _child != null;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: MapSpotCardHost.openDuration,
      reverseDuration: MapSpotCardHost.closeDuration,
    )..addStatusListener(_onStatus);
    _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    _take();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduce = KitMotion.reduce(context);
    if (_child != null && !_c.isAnimating && _c.value == 0 && widget.child != null) _open();
  }

  @override
  void didUpdateWidget(MapSpotCardHost old) {
    super.didUpdateWidget(old);
    if (widget.child != null) {
      final wasClosed = _child == null || old.child == null;
      _take();
      if (wasClosed) _open();
    } else if (old.child != null) {
      _close();
    }
  }

  void _take() {
    if (widget.child == null) return;
    _id = widget.id;
    _child = widget.child;
    _label = widget.label;
  }

  void _open() {
    _drag = 0;
    _dragging = false;
    if (_reduce) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  void _close() {
    if (_reduce || _c.value == 0) {
      _clear();
      _c.value = 0;
    } else {
      _c.reverse();
    }
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.dismissed && widget.child == null && _child != null && mounted) setState(_clear);
  }

  void _clear() {
    _id = null;
    _child = null;
    _label = null;
    _drag = 0;
    _dragging = false;
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (_exiting) return;
    final next = _drag + d.delta.dy;
    setState(() {
      _dragging = true;
      _drag = next * _toEdge > 0 ? next : 0;
    });
  }

  void _dragEnd(DragEndDetails d) {
    if (_exiting) return;
    final v = (d.primaryVelocity ?? 0) * _toEdge;
    final far = _drag.abs() > MapSpotCardHost.closeDistance;
    if (far || v > MapSpotCardHost.closeVelocity) {
      setState(() => _dragging = false);
      widget.onClose();
      return;
    }
    setState(() {
      _dragging = false;
      _drag = 0;
    });
  }

  @override
  void dispose() {
    _curve.dispose();
    _c.dispose();
    super.dispose();
  }

  Widget _switcher(Widget child, Object? id) {
    final d = _reduce ? Duration.zero : MapSpotCardHost.switchDuration;
    final align = widget.edge == MapSpotCardEdge.top ? Alignment.topCenter : Alignment.bottomCenter;
    final switcher = AnimatedSwitcher(
      duration: d,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        alignment: align,
        clipBehavior: Clip.none,
        children: [for (final p in previous) IgnorePointer(child: p), ?current],
      ),
      child: KeyedSubtree(key: ValueKey<Object?>(id), child: child),
    );
    if (d == Duration.zero) return switcher;
    return AnimatedSize(duration: d, curve: Curves.easeOut, alignment: align, clipBehavior: Clip.none, child: switcher);
  }

  @override
  Widget build(BuildContext context) {
    final child = _child;
    if (child == null) return const SizedBox.shrink();
    final shift = DS.s(MapSpotCardHost.slide) * _toEdge;
    final exiting = _exiting;
    return RepaintBoundary(
      child: Semantics(
        key: const ValueKey('map-card-host'),
        container: true,
        liveRegion: !exiting,
        label: _label,
        child: IgnorePointer(
          key: const ValueKey('map-card-exit-guard'),
          ignoring: exiting,
          child: GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onVerticalDragUpdate: _dragUpdate,
            onVerticalDragEnd: _dragEnd,
            onVerticalDragCancel: () => setState(() {
              _dragging = false;
              _drag = 0;
            }),
            child: AnimatedContainer(
              duration: _dragging || _reduce ? Duration.zero : MapSpotCardHost.snapDuration,
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(0, _drag, 0),
              child: FadeTransition(
                opacity: _curve,
                child: AnimatedBuilder(
                  animation: _curve,
                  child: _switcher(child, _id),
                  builder: (_, c) => Transform.translate(offset: Offset(0, (1 - _curve.value) * shift), child: c),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
