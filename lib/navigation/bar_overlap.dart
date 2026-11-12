import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lays out its child normally but reports `overlap` less height, so the child paints over the box below it.
class BarOverlap extends SingleChildRenderObjectWidget {
  const BarOverlap({super.key, required this.overlap, required super.child});
  final double overlap;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBarOverlap(overlap);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderBarOverlap).overlap = overlap;
}

class _RenderBarOverlap extends RenderShiftedBox {
  _RenderBarOverlap(this._overlap) : super(null);
  double _overlap;
  set overlap(double v) {
    if (v == _overlap) return;
    _overlap = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(constraints.loosen().copyWith(minWidth: constraints.minWidth), parentUsesSize: true);
    size = constraints.constrain(Size(c.size.width, (c.size.height - _overlap).clamp(0.0, double.infinity)));
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null) return false;
    return result.addWithPaintOffset(
      offset: Offset.zero,
      position: position,
      hitTest: (r, p) => c.hitTest(r, position: p),
    );
  }
}
