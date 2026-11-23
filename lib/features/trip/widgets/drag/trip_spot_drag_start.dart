import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

typedef TripDragCallback = void Function(TripTrackedDrag drag);

class TripTrackedDrag implements Drag {
  TripTrackedDrag(this.inner, this.list, this.index, Offset start, this._onMove, this._onRelease, this._onCancel)
      : _position = start;

  final Drag inner;
  final SliverReorderableListState list;
  final int index;
  final TripDragCallback? _onMove;
  final TripDragCallback? _onRelease;
  final TripDragCallback? _onCancel;
  Offset _position;
  double dy = 0;

  Offset get position => _position;

  @override
  void update(DragUpdateDetails details) {
    _position = details.globalPosition;
    dy += details.delta.dy;
    inner.update(details);
    _onMove?.call(this);
  }

  @override
  void end(DragEndDetails details) {
    inner.end(details);
    _onRelease?.call(this);
  }

  @override
  void cancel() {
    inner.cancel();
    _onCancel?.call(this);
  }

  // Lets the list recompute its gap after the page scrolled under a still finger.
  void refeed() => inner.update(DragUpdateDetails(globalPosition: _position, delta: Offset.zero));
}

class TripSpotDragStart extends StatelessWidget {
  const TripSpotDragStart({
    super.key,
    required this.index,
    required this.child,
    this.delayed = false,
    this.delay = kLongPressTimeout,
    this.behavior = HitTestBehavior.deferToChild,
    this.onLift,
    this.onMove,
    this.onRelease,
    this.onCancel,
  });

  final int index;
  final Widget child;
  final bool delayed;
  final Duration delay;
  final HitTestBehavior behavior;
  final TripDragCallback? onLift;
  final TripDragCallback? onMove;
  final TripDragCallback? onRelease;
  final TripDragCallback? onCancel;

  static int? _handlePointer;

  @override
  Widget build(BuildContext context) => Listener(
        behavior: behavior,
        onPointerDown: (e) => _start(context, e),
        child: child,
      );

  void _start(BuildContext context, PointerDownEvent event) {
    // The handle sits inside the long-press area and gets the pointer first.
    if (!delayed) {
      _handlePointer = event.pointer;
    } else if (_handlePointer == event.pointer) {
      return;
    }
    final list = SliverReorderableList.maybeOf(context);
    if (list == null) return;
    final MultiDragGestureRecognizer recognizer = delayed
        ? DelayedMultiDragGestureRecognizer(delay: delay, debugOwner: this)
        : ImmediateMultiDragGestureRecognizer(debugOwner: this);
    recognizer.gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    list.startItemDragReorder(index: index, event: event, recognizer: recognizer);
    final sdkStart = recognizer.onStart;
    if (sdkStart == null) return;
    recognizer.onStart = (position) {
      final inner = sdkStart(position);
      if (inner == null) return null;
      final drag = TripTrackedDrag(inner, list, index, position, onMove, onRelease, onCancel);
      onLift?.call(drag);
      return drag;
    };
  }
}
