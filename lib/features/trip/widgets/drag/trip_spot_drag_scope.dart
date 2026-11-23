import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../trip_constants.dart';
import '../../utils/trip_drag_slots.dart';

@immutable
class TripDragState {
  final int day;
  final int from;
  final int slot;
  final int? targetDay;
  final int targetIndex;
  final bool refused;
  final bool foreign;

  const TripDragState({
    required this.day,
    required this.from,
    required this.slot,
    this.targetDay,
    this.targetIndex = 0,
    this.refused = false,
    this.foreign = false,
  });

  bool isTarget(int d) => targetDay == d && !foreign;

  @override
  bool operator ==(Object other) =>
      other is TripDragState &&
      other.day == day &&
      other.from == from &&
      other.slot == slot &&
      other.targetDay == targetDay &&
      other.targetIndex == targetIndex &&
      other.refused == refused &&
      other.foreign == foreign;

  @override
  int get hashCode => Object.hash(day, from, slot, targetDay, targetIndex, refused, foreign);
}

class TripDragHaptics {
  static void lift() => HapticFeedback.selectionClick();
  static void slot() => HapticFeedback.selectionClick();
  static void drop() => HapticFeedback.lightImpact();
}

abstract interface class TripDayDropTarget {
  int get day;
  int get leg;
  Rect? get globalRect;
  List<Rect> rowRects();
}

enum TripDropKind { source, target, outside }

class TripSpotDragScope extends StatefulWidget {
  final Widget child;

  const TripSpotDragScope({super.key, required this.child});

  static TripSpotDragScopeState? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_TripSpotDragScopeData>()?.state;

  @override
  State<TripSpotDragScope> createState() => TripSpotDragScopeState();
}

class TripSpotDragScopeState extends State<TripSpotDragScope> {
  final ValueNotifier<TripDragState?> drag = ValueNotifier(null);
  final Map<int, TripDayDropTarget> _targets = {};
  final Map<int, bool> _allowed = {};
  EdgeDraggingAutoScroller? _auto;
  VoidCallback? _onScrolled;
  bool Function(int day)? _canDrop;
  int? _sourceLeg;
  TripDropKind _kind = TripDropKind.source;

  TripDropKind get dropKind => _kind;

  void register(int day, TripDayDropTarget t) => _targets[day] = t;

  void unregister(int day, TripDayDropTarget t) {
    if (identical(_targets[day], t)) _targets.remove(day);
  }

  void begin({required int day, required int from, required bool Function(int day) canDrop}) {
    _canDrop = canDrop;
    _allowed.clear();
    _sourceLeg = _targets[day]?.leg;
    _kind = TripDropKind.source;
    drag.value = TripDragState(day: day, from: from, slot: from);
  }

  void update({required int slot, required Rect proxy}) {
    final prev = drag.value;
    if (prev == null) return;
    final centre = proxy.center;
    TripDayDropTarget? hit;
    for (final t in _targets.values) {
      final r = t.globalRect;
      if (r != null && r.contains(centre)) {
        hit = t;
        break;
      }
    }
    final TripDragState next;
    if (hit == null || hit.day == prev.day) {
      _kind = hit == null && _sourceLeg != null ? TripDropKind.outside : TripDropKind.source;
      next = TripDragState(day: prev.day, from: prev.from, slot: slot);
    } else {
      _kind = TripDropKind.target;
      final foreign = _sourceLeg != null && hit.leg != _sourceLeg;
      final allowed = !foreign && _allowed.putIfAbsent(hit.day, () => _canDrop?.call(hit!.day) ?? false);
      next = TripDragState(
        day: prev.day,
        from: prev.from,
        slot: slot,
        targetDay: hit.day,
        targetIndex: foreign ? 0 : TripDragSlots.crossDayIndex(hit.rowRects(), centre.dy),
        refused: !allowed,
        foreign: foreign,
      );
    }
    if (next == prev) return;
    final t = next.targetDay;
    if (t != null) {
      if (!next.foreign && (prev.targetDay != t || prev.targetIndex != next.targetIndex || prev.foreign)) TripDragHaptics.slot();
    } else if (prev.slot != slot) {
      TripDragHaptics.slot();
    }
    drag.value = next;
  }

  void end() {
    _canDrop = null;
    _allowed.clear();
    _sourceLeg = null;
    _kind = TripDropKind.source;
  }

  void startAutoScroll(ScrollableState scrollable, VoidCallback onScrolled) {
    _auto?.stopAutoScroll();
    _onScrolled = onScrolled;
    _auto = EdgeDraggingAutoScroller(
      scrollable,
      velocityScalar: TripConstants.dragAutoScrollVelocity,
      onScrollViewScrolled: _scrolled,
    );
  }

  void feed(Rect proxy) => _auto?.startAutoScrollIfNecessary(proxy);

  void _scrolled() => _onScrolled?.call();

  void stopAutoScroll() {
    _auto?.stopAutoScroll();
    _auto = null;
    _onScrolled = null;
  }

  @override
  void dispose() {
    stopAutoScroll();
    drag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _TripSpotDragScopeData(state: this, child: widget.child);
}

class _TripSpotDragScopeData extends InheritedWidget {
  final TripSpotDragScopeState state;

  const _TripSpotDragScopeData({required this.state, required super.child});

  @override
  bool updateShouldNotify(_TripSpotDragScopeData oldWidget) => oldWidget.state != state;
}
