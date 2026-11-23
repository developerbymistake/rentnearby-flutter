import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../trip_constants.dart';

@immutable
class TripDragState {
  final int day;
  final int from;
  final int slot;

  const TripDragState({required this.day, required this.from, required this.slot});

  @override
  bool operator ==(Object other) => other is TripDragState && other.day == day && other.from == from && other.slot == slot;

  @override
  int get hashCode => Object.hash(day, from, slot);
}

class TripDragHaptics {
  static void lift() => HapticFeedback.selectionClick();
  static void slot() => HapticFeedback.selectionClick();
  static void drop() => HapticFeedback.lightImpact();
}

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
  EdgeDraggingAutoScroller? _auto;
  VoidCallback? _onScrolled;

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
